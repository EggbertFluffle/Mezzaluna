const SceneNodeData = @This();

const std = @import("std");
const wlr = @import("wlroots");
const wl = @import("wayland").server.wl;

const View = @import("View.zig");
const LayerSurface = @import("LayerSurface.zig");

const gpa = std.heap.c_allocator;

pub const Data = union(enum) {
  view: *View,
  layer_surface: *LayerSurface,
};

node: *wlr.SceneNode,
data: Data,
destroy: wl.Listener(void) = wl.Listener(void).init(handleDestroy),

pub fn setData(node: *wlr.SceneNode, data: Data) !void {
  const scene_node_data = try gpa.create(SceneNodeData);

  scene_node_data.* = .{
    .node = node,
    .data = data,
  };
  node.data = scene_node_data;

  node.events.destroy.add(&scene_node_data.destroy);
}

fn handleDestroy(listener: *wl.Listener(void)) void {
  const scene_node_data: *SceneNodeData = @fieldParentPtr("destroy", listener);

  scene_node_data.destroy.link.remove();
  scene_node_data.node.data = null;

  gpa.destroy(scene_node_data);
}

pub fn getFromNode(node: *wlr.SceneNode) ?*SceneNodeData {
  var n = node;
  while (true) {
    if (@as(?*SceneNodeData, @alignCast(@ptrCast(n.data)))) |scene_node_data| {
      return scene_node_data;
    }
    if (n.parent) |parent_tree| {
      n = &parent_tree.node;
    } else {
      return null;
    }
  }
}
