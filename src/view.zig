const View = @This();

const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Utils = @import("utils.zig");

const gpa = std.heap.c_allocator;
const server = &@import("main.zig").server;

mapped: bool,
focused: bool,
id: u64,

// workspace: Workspace,
xdg_toplevel: *wlr.XdgToplevel,
xdg_toplevel_decoration: ?*wlr.XdgToplevelDecorationV1,
scene_tree: *wlr.SceneTree,

// Surface Listeners
map: wl.Listener(void) = .init(handleMap),
unmap: wl.Listener(void) = .init(handleUnmap),
commit: wl.Listener(*wlr.Surface) = .init(handleCommit),
new_popup: wl.Listener(*wlr.XdgPopup) = .init(handleNewPopup),

ack_configure: wl.Listener(*wlr.XdgSurface.Configure) = .init(handleAckConfigure),

// XdgTopLevel Listeners
destroy: wl.Listener(void) = .init(handleDestroy),

request_resize: wl.Listener(*wlr.XdgToplevel.event.Resize) = .init(handleRequestResize),
request_move: wl.Listener(*wlr.XdgToplevel.event.Move) = .init(handleRequestMove),
request_fullscreen: wl.Listener(void) = .init(handleRequestFullscreen),

// Do we need to add these
// request_show_window_menu: wl.Listener(comptime T: type) = .init(handleRequestShowWindowMenu),
// request_minimize: wl.Listener(comptime T: type) = .init(handleRequestMinimize),
// request_maximize: wl.Listener(comptime T: type) = .init(handleRequestMaximize),

set_app_id: wl.Listener(void) = .init(handleSetAppId),
set_title: wl.Listener(void) = .init(handleSetTitle),

// Do we need to add this
// set_parent: wl.Listener(void) = .init(handleSetParent),

pub fn initFromTopLevel(xdg_toplevel: *wlr.XdgToplevel) *View {
  errdefer Utils.oomPanic();

  const self = try gpa.create(View);
  errdefer gpa.destroy(self);

  self.* = .{
    .xdg_toplevel = xdg_toplevel,
    .focused = false,
    .scene_tree = undefined,
    .xdg_toplevel_decoration = null,
    .mapped = false,
    .id = @intFromPtr(xdg_toplevel),
  };

  self.xdg_toplevel.base.surface.events.unmap.add(&self.unmap);

  // Add new Toplevel to focused output instead of some random shit
  // This is where we find out where to tile the widow, but not NOW
  // We need lua for that
  // self.scene_tree = try server.root.workspaces.items[0].createSceneXdgSurface(xdg_toplevel.base);
  self.scene_tree = try server.root.scene.tree.createSceneXdgSurface(xdg_toplevel.base);

  self.scene_tree.node.data = self;
  self.xdg_toplevel.base.data = self.scene_tree;

  self.xdg_toplevel.events.destroy.add(&self.destroy);
  self.xdg_toplevel.base.surface.events.map.add(&self.map);
  self.xdg_toplevel.base.surface.events.commit.add(&self.commit);
  self.xdg_toplevel.base.events.new_popup.add(&self.new_popup);

  try server.root.views.put(self.id, self);

  return self;
}

pub fn deinit(self: *View) void {
  self.map.link.remove();
  self.unmap.link.remove();
  self.commit.link.remove();

  self.destroy.link.remove();
  self.request_move.link.remove();
  self.request_resize.link.remove();
}

// Handle borders to appropriate colros make necessary notifications
pub fn setFocus(self: *View, focus: bool) void {
  self.focused = focus;
}

// --------- XdgTopLevel event handlers ---------
fn handleMap(listener: *wl.Listener(void)) void {
  const view: *View = @fieldParentPtr("map", listener);
  std.log.debug("Mapping view '{s}'", .{view.xdg_toplevel.title orelse "(unnamed)"});

  view.xdg_toplevel.events.request_fullscreen.add(&view.request_fullscreen);
  view.xdg_toplevel.events.request_move.add(&view.request_move);
  view.xdg_toplevel.events.request_resize.add(&view.request_resize);
  view.xdg_toplevel.events.set_app_id.add(&view.set_app_id);
  view.xdg_toplevel.events.set_title.add(&view.set_title);
  // view.xdg_toplevel.events.set_parent.add(&view.set_parent);

  const xdg_surface = view.xdg_toplevel.base;
  server.seat.wlr_seat.keyboardNotifyEnter(
    xdg_surface.surface,
    server.keyboard.wlr_keyboard.keycodes[0..server.keyboard.wlr_keyboard.num_keycodes],
    &server.keyboard.wlr_keyboard.modifiers
  );

  if(view.xdg_toplevel_decoration) |decoration| {
    _ = decoration.setMode(wlr.XdgToplevelDecorationV1.Mode.server_side);
  }

  // Here is where we should tile and set size

  view.mapped = true;
}

fn handleUnmap(listener: *wl.Listener(void)) void {
  const view: *View = @fieldParentPtr("unmap", listener);
  std.log.debug("Unmapping view '{s}'", .{view.xdg_toplevel.title orelse "(unnamed)"});

  view.request_fullscreen.link.remove();
  view.request_move.link.remove();
  view.request_resize.link.remove();
  view.set_title.link.remove();
  view.set_app_id.link.remove();

  // Why does this crash mez???
  // view.ack_configure.link.remove();

  view.mapped = false;
}

fn handleDestroy(listener: *wl.Listener(void)) void {
  const view: *View = @fieldParentPtr("destroy", listener);

  // Remove decorations

  view.map.link.remove();
  view.unmap.link.remove();
  view.commit.link.remove();
  view.destroy.link.remove();
  view.new_popup.link.remove();

  view.xdg_toplevel.base.surface.data = null;

  view.scene_tree.node.destroy();
  // Destroy popups

  _ = server.root.views.remove(view.id);

  gpa.destroy(view);
}

fn handleCommit(listener: *wl.Listener(*wlr.Surface), _: *wlr.Surface) void {
  const view: *View = @fieldParentPtr("commit", listener);

  // On the first commit, send a configure to tell the client it can proceed
  if (view.xdg_toplevel.base.initial_commit) {
    _ = view.xdg_toplevel.setSize(640, 360); // 0,0 means "you decide the size"
  }
}

// --------- XdgToplevel Event Handlers ---------
fn handleNewPopup(listener: *wl.Listener(*wlr.XdgPopup), popup: *wlr.XdgPopup) void {
  _ = listener;
  _ = popup;
  std.log.err("Unimplemented view handle new popup", .{});
}

fn handleRequestMove(
  _: *wl.Listener(*wlr.XdgToplevel.event.Move),
  _: *wlr.XdgToplevel.event.Move
) void {
  // const view: *View = @fieldParentPtr("request_move", listener);

  std.log.debug("The clients should not be request moves", .{});

  // server.cursor.moveView(view);
  // server.cursor.grabbed_view = view;
  // server.cursor.mode = .move;
  // server.cursor.grab_x = server.cursor.wlr_cursor.x - @as(f64, @floatFromInt(view.geometry.x));
  // server.cursor.grab_y = server.cursor.wlr_cursor.y - @as(f64, @floatFromInt(view.geometry.y));
}

fn handleRequestResize(
  _: *wl.Listener(*wlr.XdgToplevel.event.Resize),
  _: *wlr.XdgToplevel.event.Resize
) void {
  // const view: *View = @fieldParentPtr("request_resize", listener);

  std.log.debug("The clients should not be request moves", .{});

  // server.cursor.grabbed_view = view;
  // server.cursor.mode = .resize;
  // server.cursor.resize_edges = event.edges;
  //
  // const box = view.xdg_toplevel.base.geometry;
  //
  // const border_x = view.geometry.x + box.x + if (event.edges.right) box.width else 0;
  // const border_y = view.geometry.y + box.y + if (event.edges.bottom) box.height else 0;
  // server.cursor.grab_x = server.cursor.wlr_cursor.x - @as(f64, @floatFromInt(border_x));
  // server.cursor.grab_y = server.cursor.wlr_cursor.y - @as(f64, @floatFromInt(border_y));
  //
  // server.cursor.grab_box = box;
  // server.cursor.grab_box.x += view.geometry.x;
  // server.cursor.grab_box.y += view.geometry.y;
}

fn handleAckConfigure(
  listener: *wl.Listener(*wlr.XdgSurface.Configure),
  _: *wlr.XdgSurface.Configure,
) void {
  const view: *View = @fieldParentPtr("ack_configure", listener);
  _ = view;
  std.log.err("Unimplemented act configure", .{});
}

fn handleRequestFullscreen(
  listener: *wl.Listener(void)
) void {
  const view: *View = @fieldParentPtr("request_fullscreen", listener);
  _ = view;
  std.log.err("Unimplemented request fullscreen", .{});
}

fn handleRequestMinimize(
  listener: *wl.Listener(void)
) void {
  const view: *View = @fieldParentPtr("request_fullscreen", listener);
  _ = view;
  std.log.err("Unimplemented request minimize", .{});
}

fn handleRequestMaximize(
  listener: *wl.Listener(void)
) void {
  const view: *View = @fieldParentPtr("request_fullscreen", listener);
  _ = view;
  std.log.err("Unimplemented request maximize", .{});
}

fn handleSetAppId(
  listener: *wl.Listener(void)
) void {
  const view: *View = @fieldParentPtr("set_app_id", listener);
  _ = view;
  std.log.err("Unimplemented request maximize", .{});
}

fn handleSetTitle(
  listener: *wl.Listener(void)
) void {
  const view: *View = @fieldParentPtr("set_title", listener);
  _ = view;
  std.log.err("Unimplemented set title", .{});
}
