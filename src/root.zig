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
focused_output: ?*Output,

views: std.ArrayList(*View) = undefined,
workspaces: std.ArrayList(*wlr.SceneTree) = undefined,

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
    .focused_output = null,
    .xdg_toplevel_decoration_manager = try wlr.XdgDecorationManagerV1.create(server.wl_server),
    .scene_output_layout = try scene.attachOutputLayout(output_layout),
  };

  self.views = try std.ArrayList(*View).initCapacity(gpa, 10); // Should consider number better, prolly won't matter that much though
  // Even though I would never use a changing amount of workspaces, opens more extensibility
  self.workspaces = try std.ArrayList(*wlr.SceneTree).initCapacity(gpa, 10); // TODO: change to a configured number of workspaces

  // TODO: Make configurable
  for(0..9) |_| {
    try self.workspaces.append(gpa, try self.scene.tree.createSceneTree());
  }
}

pub fn deinit(self: *Root) void {
  for(self.views.items) |view| {
    view.deinit();
  }
  self.views.deinit(gpa);

  self.workspaces.deinit(gpa);

  self.output_layout.destroy();
  self.scene.tree.node.destroy();
}

pub fn addOutput(self: *Root, new_output: *Output) void {
  errdefer Utils.oomPanic();
  _ = try self.output_layout.addAuto(new_output.wlr_output);
  self.focused_output = new_output;
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

pub fn focusView(_: *Root, view: *View) void {
  if (server.seat.wlr_seat.keyboard_state.focused_surface) |previous_surface| {
    if (previous_surface == view.xdg_toplevel.base.surface) return;
    if (wlr.XdgSurface.tryFromWlrSurface(previous_surface)) |xdg_surface| {
      _ = xdg_surface.role_data.toplevel.?.setActivated(false);
    }
  }

  view.scene_tree.node.raiseToTop();

  _ = view.xdg_toplevel.setActivated(true);

  const wlr_keyboard = server.seat.wlr_seat.getKeyboard() orelse return;
  server.seat.wlr_seat.keyboardNotifyEnter(
    view.xdg_toplevel.base.surface,
    wlr_keyboard.keycodes[0..wlr_keyboard.num_keycodes],
    &wlr_keyboard.modifiers,
  );
}
