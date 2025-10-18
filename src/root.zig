const std = @import("std");

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Output = @import("output.zig").Output;

const server = &@import("main.zig").server;

pub const Root = struct {
  scene: *wlr.Scene,

  output_layout: *wlr.OutputLayout,

  new_output: wl.Listener(*wlr.Output),

  pub fn init(root: *Root) !void {
    std.log.info("Creating root of mezzaluna", .{});

    const output_layout = try wlr.OutputLayout.create(server.wl_server);
    errdefer output_layout.destroy();

    const scene = try wlr.Scene.create();
    errdefer scene.tree.node.destroy();

    root.* = .{
      .scene = scene,
      .output_layout = output_layout,

      .new_output = .init(handleNewOutput),
    };

    server.backend.events.new_output.add(&root.new_output);
  }

  pub fn addOutput(self: *Root, new_output: *Output) void {
    _ = self.output_layout.addAuto(new_output.wlr_output) catch {
      std.log.err("failed to add new output to output layout\n", .{});
      return;
    };

    _ = self.scene.createSceneOutput(new_output.wlr_output) catch {
      std.log.err("failed to create scene output for new output", .{});
      return;
    };
  }
};

fn handleNewOutput(_: *wl.Listener(*wlr.Output), wlr_output: *wlr.Output) void {
  std.log.info("Handling a new output - {s}", .{wlr_output.name});

  if (!wlr_output.initRender(server.allocator, server.renderer)) return;

  var state = wlr.Output.State.init();
  defer state.finish();

  state.setEnabled(true);

  if (wlr_output.preferredMode()) |mode| {
    state.setMode(mode);
  }
  if (!wlr_output.commitState(&state)) return;

  const new_output = Output.create(wlr_output) catch {
    std.log.err("failed to allocate new output", .{});
    wlr_output.destroy();
    return;
  };

  server.root.addOutput(new_output);
}
