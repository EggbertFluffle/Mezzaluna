const Root = @This();

const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Output = @import("output.zig");
const TopLevel = @import("toplevel.zig");

const server = &@import("main.zig").server;
const gpa = std.heap.c_allocator;

scene: *wlr.Scene,

output_layout: *wlr.OutputLayout,

new_output: wl.Listener(*wlr.Output),

all_top_levels: std.ArrayList(*TopLevel),

pub fn init(root: *Root) !void {
  std.log.info("Creating root of mezzaluna\n", .{});

  const output_layout = try wlr.OutputLayout.create(server.wl_server);
  errdefer output_layout.destroy();

  const scene = try wlr.Scene.create();
  errdefer scene.tree.node.destroy();

  root.* = .{
    .scene = scene,
    .output_layout = output_layout,

    .new_output = .init(handleNewOutput),

    .all_top_levels = try .initCapacity(gpa, 10),
  };

  server.backend.events.new_output.add(&root.new_output);
}

pub fn addOutput(self: *Root, new_output: *Output) void {
  _ = self.output_layout.addAuto(new_output.wlr_output) catch {
    std.log.err("failed to add new output to output layout\n", .{});
    return;
  };
}

pub fn addTopLevel(self: *Root, top_level: *TopLevel) void {
  self.all_top_levels.append(gpa, top_level) catch {
    std.log.err("Out of memory to append top level", .{});
  };

  // self.scene.tree.children.append(wlr.SceneNode)
}

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

