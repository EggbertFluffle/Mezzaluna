/// The root of Mezzaluna is, you guessed it, the root of many of the systems mez needs:
///   - Managing outputs
///   -
const Root = @This();

const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Output = @import("output.zig");
const View = @import("view.zig");
const Utils = @import("utils.zig");

const server = &@import("main.zig").server;
const gpa = std.heap.c_allocator;

xdg_toplevel_decoration_manager: *wlr.XdgDecorationManagerV1,

scene: *wlr.Scene,
scene_output_layout: *wlr.SceneOutputLayout,

output_layout: *wlr.OutputLayout,

pub fn init(self: *Root) void {
  std.log.info("Creating root of mezzaluna\n", .{});

  errdefer Utils.oomPanic();

  const output_layout = try wlr.OutputLayout.create(server.wl_server);
  errdefer output_layout.destroy();

  const scene = try wlr.Scene.create();
  errdefer scene.tree.node.destroy();

  self.* = .{
    .scene = scene,
    .output_layout = output_layout,
    .xdg_toplevel_decoration_manager = try wlr.XdgDecorationManagerV1.create(server.wl_server),
    .scene_output_layout = try scene.attachOutputLayout(output_layout),
  };
}

pub fn deinit(self: *Root) void {
  var it = self.scene.tree.children.iterator(.forward);

  while(it.next()) |node| {
    if(node.data == null) continue;

    const view: *View = @ptrCast(@alignCast(node.data.?));
    view.deinit();
  }

  self.output_layout.destroy();
  self.scene.tree.node.destroy();
}

pub fn viewById(self: *Root, id: u64) ?*View {
  var it = self.scene.tree.children.iterator(.forward);

  while(it.next()) |node| {
    if(node.data == null) continue;

    const view: *View = @as(*View, @ptrCast(@alignCast(node.data.?)));
    if(view.id == id) return view;
  }

  return null;
}

pub fn addOutput(self: *Root, new_output: *Output) void {
  errdefer Utils.oomPanic();
  const layout_output = try self.output_layout.addAuto(new_output.wlr_output);
  self.scene_output_layout.addOutput(layout_output, new_output.scene_output);
  server.seat.focusOutput(new_output);
}

const ViewAtResult = struct {
    view: *View,
    surface: *wlr.Surface,
    sx: f64,
    sy: f64,
};

pub fn viewAt(self: *Root, lx: f64, ly: f64) ?ViewAtResult {
  var sx: f64 = undefined;
  var sy: f64 = undefined;

  if (self.scene.tree.node.at(lx, ly, &sx, &sy)) |node| {
    if (node.type != .buffer) return null;
    const scene_buffer = wlr.SceneBuffer.fromNode(node);
    const scene_surface = wlr.SceneSurface.tryFromBuffer(scene_buffer) orelse return null;

    var it: ?*wlr.SceneTree = node.parent;

    while (it) |n| : (it = n.node.parent) {
      if (n.node.data) |data_ptr| {
        if (@as(?*View, @ptrCast(@alignCast(data_ptr)))) |view| {
          return ViewAtResult{
            .view = view,
            .surface = scene_surface.surface,
            .sx = sx,
            .sy = sy,
          };
        }
      }
    }
  }
  return null;
}
