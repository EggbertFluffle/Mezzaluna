const Output = @This();

const std = @import("std");
const posix = std.posix;
const gpa = std.heap.c_allocator;
const server = &@import("main.zig").server;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Server = @import("server.zig");

wlr_output: *wlr.Output,
scene_output: *wlr.SceneOutput,

frame: wl.Listener(*wlr.Output) = .init(handleFrame),
request_state: wl.Listener(*wlr.Output.event.RequestState) = .init(handleRequestState),
destroy: wl.Listener(*wlr.Output) = .init(handleDestroy),

// The wlr.Output should be destroyed by the caller on failure to trigger cleanup.
pub fn create(wlr_output: *wlr.Output) !*Output {
  const output = try gpa.create(Output);

  output.* = .{
    .wlr_output = wlr_output,
    .scene_output = try server.root.scene.createSceneOutput(wlr_output)
  };

  wlr_output.events.frame.add(&output.frame);
  wlr_output.events.request_state.add(&output.request_state);
  wlr_output.events.destroy.add(&output.destroy);

  std.log.debug("adding output: {s}", .{output.wlr_output.name});

  // I don't think we need the result of this
  const layout_output = try server.root.output_layout.addAuto(wlr_output);
  server.root.scene_output_layout.addOutput(layout_output, output.scene_output);

  return output;
}

// Conflicting name with destroy listener
// Should probably add _listner as a postfix to listeners
//
// pub fn destroy(output: *Output) void {
//   gpa.free(output);
// }

fn handleRequestState(
  listener: *wl.Listener(*wlr.Output.event.RequestState),
  event: *wlr.Output.event.RequestState,
) void {
  std.log.debug("Handling request state", .{});
  const output: *Output = @fieldParentPtr("request_state", listener);

  if (!output.wlr_output.commitState(event.state)) {
    std.log.warn("failed to set output state {}", .{event.state});
  }
}

fn handleFrame(
  _: *wl.Listener(*wlr.Output),
  wlr_output: *wlr.Output
) void {
  std.log.debug("Handling frame for {s}", .{wlr_output.name});

  const scene_output = server.root.scene.getSceneOutput(wlr_output);

  if(scene_output == null) {
    std.log.err("Unable to get scene output to render", .{});
    return;
  }

  // std.log.info("Rendering commited scene output\n", .{});
  _ = scene_output.?.commit(null);

  var now = posix.clock_gettime(posix.CLOCK.MONOTONIC) catch @panic("CLOCK_MONOTONIC not supported");
  scene_output.?.sendFrameDone(&now);
}

fn handleDestroy(
  listener: *wl.Listener(*wlr.Output),
  _: *wlr.Output
) void {
  std.log.debug("Handling destroy", .{});
  const output: *Output = @fieldParentPtr("destroy", listener);

  std.log.debug("removing output: {s}", .{output.wlr_output.name});

  output.frame.link.remove();
  output.request_state.link.remove();
  output.destroy.link.remove();

  gpa.destroy(output);
}
