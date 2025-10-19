const std = @import("std");
const posix = std.posix;
const gpa = std.heap.c_allocator;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const server = &@import("main.zig").server;

pub const Output = struct {
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

    return output;
  }

  pub fn handleFrame(_: *wl.Listener(*wlr.Output), wlr_output: *wlr.Output) void {
    const scene_output = server.scene.getSceneOutput(wlr_output);

    if(scene_output) |so| {
      std.log.info("Rendering commitin scene output\n", .{});
      _ = so.commit(null);

      var now = posix.clock_gettime(posix.CLOCK.MONOTONIC) catch @panic("CLOCK_MONOTONIC not supported");
      so.sendFrameDone(&now);
    }

  }

  pub fn handleRequestState(
  listener: *wl.Listener(*wlr.Output.event.RequestState),
  event: *wlr.Output.event.RequestState,
) void {
    const output: *Output = @fieldParentPtr("request_state", listener);

    _ = output.wlr_output.commitState(event.state);
  }

  pub fn handleDestroy(listener: *wl.Listener(*wlr.Output), _: *wlr.Output) void {
    const output: *Output = @fieldParentPtr("destroy", listener);

    output.frame.link.remove();
    output.request_state.link.remove();
    output.destroy.link.remove();

    gpa.destroy(output);
  }
};
