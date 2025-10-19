const Root = @This();

const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Output = @import("output.zig");
const View = @import("view.zig");

const server = &@import("main.zig").server;
const gpa = std.heap.c_allocator;

scene: *wlr.Scene,
scene_tree: ?*wlr.Scene,
scene_output_layout: *wlr.SceneOutputLayout,

output_layout: *wlr.OutputLayout,

all_views: std.ArrayList(*View),

pub fn init(self: *Root) !void {
  std.log.info("Creating root of mezzaluna\n", .{});

  const output_layout = try wlr.OutputLayout.create(server.wl_server);
  errdefer output_layout.destroy();

  const scene = try wlr.Scene.create();
  errdefer scene.tree.node.destroy();

  self.* = .{
    .scene = scene,
    .scene_tree = null,
    .output_layout = output_layout,
    .scene_output_layout = try scene.attachOutputLayout(output_layout),


    .all_views = try .initCapacity(gpa, 10),
  };
}

pub fn deinit(self: *Root) void {
  self.output_layout.destroy();
  self.scene.tree.node.destroy();
}

pub fn addOutput(self: *Root, new_output: *Output) void {
  _ = self.output_layout.addAuto(new_output.wlr_output) catch {
    std.log.err("failed to add new output to output layout\n", .{});
    return;
  };
}

pub fn addView(self: *Root, view: *View) void {
  self.scene_tree = self.scene.tree.createSceneXdgSurface(view.xdg_toplevel.base) catch {
    std.log.err("Unable to create scene node for new view", .{});
  };

  self.all_views.append(gpa, view) catch {
    std.log.err("Out of memory to append view", .{});
    self.scene_tree = null;
    return;
  };

  std.log.debug("View added succesfully", .{});
}

const ViewAtResult = struct {
  // TODO: uncomment when we have toplevels
  // toplevel: *Toplevel,
  surface: *wlr.Surface,
  sx: f64,
  sy: f64,
};

pub fn viewAt(self: *Root, lx: f64, ly: f64) ?ViewAtResult {
  var sx: f64 = undefined;
  var sy: f64 = undefined;
  if (self.scene.tree.node.at(lx, ly, &sx, &sy)) |node| {
    if (node.type != .buffer) return null;
    // TODO: uncomment when we have toplevels
    // const scene_buffer = wlr.SceneBuffer.fromNode(node);
    // const scene_surface = wlr.SceneSurface.tryFromBuffer(scene_buffer) orelse return null;

    var it: ?*wlr.SceneTree = node.parent;
    while (it) |n| : (it = n.node.parent) {
      // if (@as(?*Toplevel, @ptrCast(@alignCast(n.node.data)))) |toplevel| {
      //   return ViewAtResult{
      //     .toplevel = toplevel,
      //     .surface = scene_surface.surface,
      //     .sx = sx,
      //     .sy = sy,
      //   };
      // }
    }
  }
  return null;
}
