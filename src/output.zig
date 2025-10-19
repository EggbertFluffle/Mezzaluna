const Output = @This();

const std = @import("std");
const posix = std.posix;
const gpa = std.heap.c_allocator;
const server = &@import("main.zig").server;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Server = @import("server.zig");

wlr_output: *wlr.Output,

frame: wl.Listener(*wlr.Output) = .init(handleFrame),
request_state: wl.Listener(*wlr.Output.event.RequestState) = .init(handleRequestState),
destroy: wl.Listener(*wlr.Output) = .init(handleDestroy),

// The wlr.Output should be destroyed by the caller on failure to trigger cleanup.
pub fn create(wlr_output: *wlr.Output) !*Output {
  const output = try gpa.create(Output);

  output.* = .{
    .wlr_output = wlr_output,
  };
  wlr_output.events.frame.add(&output.frame);
  wlr_output.events.request_state.add(&output.request_state);
  wlr_output.events.destroy.add(&output.destroy);

  std.log.debug("adding output: {s}", .{output.*.wlr_output.*.name});

  const layout_output = try server.output_layout.addAuto(wlr_output);

  const scene_output = try server.scene.createSceneOutput(wlr_output);
  server.scene_output_layout.addOutput(layout_output, scene_output);

  return output;
}

pub fn handleRequestState(
listener: *wl.Listener(*wlr.Output.event.RequestState),
event: *wlr.Output.event.RequestState,
  ) void {
  std.log.debug("Handling request state", .{});
  const output: *Output = @fieldParentPtr("request_state", listener);

  if (!output.wlr_output.commitState(event.state)) {
    std.log.warn("failed to set output state {}", .{event.state});
  }
}

pub fn handleFrame(_: *wl.Listener(*wlr.Output), wlr_output: *wlr.Output) void {
  std.log.debug("Handling frame for {s}", .{wlr_output.name});

  const scene_output = server.scene.*.getSceneOutput(wlr_output);

  if(scene_output) |so| {
    std.log.info("Rendering commited scene output\n", .{});
    _ = so.commit(null);

    var now = posix.clock_gettime(posix.CLOCK.MONOTONIC) catch @panic("CLOCK_MONOTONIC not supported");
    so.sendFrameDone(&now);
  }

}

pub fn handleDestroy(listener: *wl.Listener(*wlr.Output), _: *wlr.Output) void {
  std.log.debug("Handling destroy", .{});
  const output: *Output = @fieldParentPtr("destroy", listener);

  std.log.debug("removing output: {s}", .{output.*.wlr_output.*.name});

  output.frame.link.remove();
  output.request_state.link.remove();
  output.destroy.link.remove();

  gpa.destroy(output);
}
