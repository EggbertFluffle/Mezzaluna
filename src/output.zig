const Output = @This();

const std = @import("std");
const posix = std.posix;
const gpa = std.heap.c_allocator;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Server = @import("server.zig");

server: *Server,
wlr_output: *wlr.Output,

frame: wl.Listener(*wlr.Output) = .init(handleFrame),
request_state: wl.Listener(*wlr.Output.event.RequestState) = .init(handleRequestState),
destroy: wl.Listener(*wlr.Output) = .init(handleDestroy),

// The wlr.Output should be destroyed by the caller on failure to trigger cleanup.
pub fn create(server: *Server, wlr_output: *wlr.Output) !void {
  const output = try gpa.create(Output);

  output.* = .{
    .server = server,
    .wlr_output = wlr_output,
  };
  wlr_output.events.frame.add(&output.frame);
  wlr_output.events.request_state.add(&output.request_state);
  wlr_output.events.destroy.add(&output.destroy);

  std.log.debug("adding output: {s}", .{output.*.wlr_output.*.name});

  const layout_output = try server.output_layout.addAuto(wlr_output);

  const scene_output = try server.scene.createSceneOutput(wlr_output);
  server.scene_output_layout.addOutput(layout_output, scene_output);
}

pub fn handleFrame(listener: *wl.Listener(*wlr.Output), _: *wlr.Output) void {
  const output: *Output = @fieldParentPtr("frame", listener);

  const scene_output = output.server.scene.getSceneOutput(output.wlr_output).?;
  _ = scene_output.commit(null);

  var now = posix.clock_gettime(posix.CLOCK.MONOTONIC) catch @panic("CLOCK_MONOTONIC not supported");
  scene_output.sendFrameDone(&now);
}

pub fn handleRequestState(
listener: *wl.Listener(*wlr.Output.event.RequestState),
event: *wlr.Output.event.RequestState,
  ) void {
  const output: *Output = @fieldParentPtr("request_state", listener);

  if (!output.wlr_output.commitState(event.state)) {
    std.log.warn("failed to set output state {}", .{event.state});
  }
}

pub fn handleDestroy(listener: *wl.Listener(*wlr.Output), _: *wlr.Output) void {
  const output: *Output = @fieldParentPtr("destroy", listener);

  std.log.debug("removing output: {s}", .{output.*.wlr_output.*.name});

  output.frame.link.remove();
  output.request_state.link.remove();
  output.destroy.link.remove();

  gpa.destroy(output);
}
