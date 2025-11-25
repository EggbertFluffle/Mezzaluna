const Output = @This();

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");
const std = @import("std");
const Server = @import("server.zig");
const Utils = @import("utils.zig");

const posix = std.posix;
const gpa = std.heap.c_allocator;
const server = &@import("main.zig").server;

focused: bool,

wlr_output: *wlr.Output,
state: wlr.Output.State,
scene_output: *wlr.SceneOutput,

frame: wl.Listener(*wlr.Output) = .init(handleFrame),
request_state: wl.Listener(*wlr.Output.event.RequestState) = .init(handleRequestState),
destroy: wl.Listener(*wlr.Output) = .init(handleDestroy),

// The wlr.Output should be destroyed by the caller on failure to trigger cleanup.
pub fn init(wlr_output: *wlr.Output) ?*Output {
  errdefer Utils.oomPanic();

  const output = try gpa.create(Output);

  output.* = .{
    .focused = false,
    .wlr_output = wlr_output,
    .scene_output = try server.root.scene.createSceneOutput(wlr_output),
    .state = wlr.Output.State.init()
  };

  wlr_output.events.frame.add(&output.frame);
  wlr_output.events.request_state.add(&output.request_state);
  wlr_output.events.destroy.add(&output.destroy);

  errdefer deinit(output);

  if(!wlr_output.initRender(server.allocator, server.renderer)) {
    std.log.err("Unable to start output {s}", .{wlr_output.name});
    return null;
  }

  output.state.setEnabled(true);

  if (wlr_output.preferredMode()) |mode| {
    output.state.setMode(mode);
  }

  if(!wlr_output.commitState(&output.state)) {
    std.log.err("Unable to commit state to output {s}", .{wlr_output.name});
    return null;
  }

  server.root.addOutput(output);

  return output;
}

pub fn deinit(output: *Output) void {
  output.frame.link.remove();
  output.request_state.link.remove();
  output.destroy.remove();

  output.state.finish();

  output.wlr_output.destroy();

  gpa.free(output);
}


// --------- WlrOutput Event Handlers ---------
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

  server.root.output_layout.remove(output.wlr_output);

  gpa.destroy(output);
}
