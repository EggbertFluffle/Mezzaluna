const View = @This();


const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Utils = @import("utils.zig");

const gpa = std.heap.c_allocator;
const server = &@import("main.zig").server;

link: wl.list.Link = undefined,
geometry: *wlr.Box = undefined,

xdg_toplevel: *wlr.XdgToplevel,
xdg_surface: *wlr.XdgSurface,
scene_tree: *wlr.SceneTree,

// Surface Listeners
map: wl.Listener(void) = .init(handleMap),
unmap: wl.Listener(void) = .init(handleUnmap),
commit: wl.Listener(*wlr.Surface) = .init(handleCommit),

// XdgTopLevel Listeners
destroy: wl.Listener(void) = .init(handleDestroy),
request_resize: wl.Listener(*wlr.XdgToplevel.event.Resize) = .init(handleRequestResize),
request_move: wl.Listener(*wlr.XdgToplevel.event.Move) = .init(handleRequestMove),

// Not yet silly
// new_popup: wl.Listener(*wlr.XdgPopup) = wl.Listener(*wlr.XdgPopup).init(handleNewPopup),

pub fn initFromTopLevel(xdg_toplevel: *wlr.XdgToplevel) *View {
  errdefer Utils.oomPanic();

  const self = try gpa.create(View);
  errdefer gpa.destroy(self);

  self.* = .{
    .xdg_toplevel = xdg_toplevel,
    .xdg_surface = xdg_toplevel.base,
    .geometry = &xdg_toplevel.base.geometry,
    .scene_tree = undefined,

  };

  // Add new Toplevel to focused output instead of some random shit
  self.scene_tree = try server.root.workspaces.items[0].createSceneXdgSurface(xdg_toplevel.base);

  self.scene_tree.node.data = self;
  self.xdg_surface.data = self.scene_tree;

  // Attach listeners
  self.xdg_surface.surface.events.map.add(&self.map);
  self.xdg_surface.surface.events.unmap.add(&self.unmap);
  self.xdg_surface.surface.events.commit.add(&self.commit);

  self.xdg_toplevel.events.destroy.add(&self.destroy);
  self.xdg_toplevel.events.request_move.add(&self.request_move);
  self.xdg_toplevel.events.request_resize.add(&self.request_resize);

  // xdg_toplevel.events.request_fullscreen.add(&self.request_fullscreen);
  // xdg_toplevel.events.request_minimize.add(&self.request_minimize);
  // xdg_toplevel.events.request_maxminize.add(&self.request_maximize);

  // xdg_toplevel.events.set_title.add(&self.set_title);
  // xdg_toplevel.events.set_app_id.add(&self.set_app_id);
  // xdg_toplevel.events.set_parent.add(&self.set_parent);

  // xdg_toplevel.events.request_show_window_menu.add(&self.request_show_window_menu);

  try server.root.views.append(gpa, self);

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

// --------- XdgTopLevel event handlers ---------
fn handleMap(listener: *wl.Listener(void)) void {
  const view: *View = @fieldParentPtr("map", listener);
  std.log.info("View mapped {s}", .{view.xdg_toplevel.title orelse "(unnamed)"});

  const xdg_surface = view.xdg_toplevel.base;
  server.seat.wlr_seat.keyboardNotifyEnter(
    xdg_surface.surface,
    server.keyboard.wlr_keyboard.keycodes[0..server.keyboard.wlr_keyboard.num_keycodes],
    &server.keyboard.wlr_keyboard.modifiers
  );
}

fn handleUnmap(listener: *wl.Listener(void)) void {
  _ = listener;
  std.log.err("Unimplemented view handle unamp", .{});
}

fn handleDestroy(listener: *wl.Listener(void)) void {
  const view: *View = @fieldParentPtr("destroy", listener);
  std.log.debug("Destroying view {s}", .{view.xdg_toplevel.title orelse "(unnamed)"});

  view.map.link.remove();
  view.unmap.link.remove();
  view.commit.link.remove();
  view.destroy.link.remove();

  // Remove this view from the list of views
  // for(server.root.all_views.items, 0..) |v, i| {
  //   if(v == view) {
  //     _ = server.root.all_views.orderedRemove(i);
  //     break;
  //   }
  // }

  gpa.destroy(view);
}

fn handleCommit(listener: *wl.Listener(*wlr.Surface), _: *wlr.Surface) void {
  const view: *View = @fieldParentPtr("commit", listener);

  // On the first commit, send a configure to tell the client it can proceed
  if (view.xdg_toplevel.base.initial_commit) {
    _ = view.xdg_toplevel.setSize(640, 360); // 0,0 means "you decide the size"
  }
}

fn handleNewPopup(listener: *wl.Listener(*wlr.XdgPopup), popup: *wlr.XdgPopup) void {
  _ = listener;
  _ = popup;
  std.log.err("Unimplemented view handle new popup", .{});
}

fn handleRequestMove(
  listener: *wl.Listener(*wlr.XdgToplevel.event.Move),
  _: *wlr.XdgToplevel.event.Move
) void {
  const view: *View = @fieldParentPtr("request_move", listener);

  server.cursor.grabbed_view = view;
  server.cursor.mode = .move;
  server.cursor.grab_x = server.cursor.wlr_cursor.x - @as(f64, @floatFromInt(view.geometry.x));
  server.cursor.grab_y = server.cursor.wlr_cursor.y - @as(f64, @floatFromInt(view.geometry.y));
}

fn handleRequestResize(
  listener: *wl.Listener(*wlr.XdgToplevel.event.Resize),
  event: *wlr.XdgToplevel.event.Resize
) void {
  const view: *View = @fieldParentPtr("request_resize", listener);

  server.cursor.grabbed_view = view;
  server.cursor.mode = .resize;
  server.cursor.resize_edges = event.edges;

  const box = view.xdg_toplevel.base.geometry;

  const border_x = view.geometry.x + box.x + if (event.edges.right) box.width else 0;
  const border_y = view.geometry.y + box.y + if (event.edges.bottom) box.height else 0;
  server.cursor.grab_x = server.cursor.wlr_cursor.x - @as(f64, @floatFromInt(border_x));
  server.cursor.grab_y = server.cursor.wlr_cursor.y - @as(f64, @floatFromInt(border_y));

  server.cursor.grab_box = box;
  server.cursor.grab_box.x += view.geometry.x;
  server.cursor.grab_box.y += view.geometry.y;
}
