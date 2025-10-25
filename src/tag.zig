const Tag = @This();

const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Output = @import("output.zig");
const View = @import("view.zig");
const Utils = @import("utils.zig");

const server = @import("main.zig").server;
const gpa = std.heap.c_allocator;

output: *Output,
scene_tree: *wlr.SceneTree,

views: std.ArrayList(*View),

pub fn init(output: *Output) Tag {
  errdefer Utils.oomPanic();
  return .{
    .output = output,
    .scene_tree = try server.root.scene.tree.createSceneTree(),
    .views = .initCapacity(gpa, 2), // Probably shouldn't be a magic number
  };
}

pub fn deinit(self: *Tag) void {
  for(self.views.items) |view| {
    view
  }
}
