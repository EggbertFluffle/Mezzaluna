const View = @This();

const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const gpa = std.heap.c_allocator;
const server = &@import("main.zig").server;

xdg_toplevel: *wlr.XdgToplevel,
scene_tree: *wlr.SceneTree,

// Surface Listeners
map: wl.Listener(void) = wl.Listener(void).init(handleMap),
unmap: wl.Listener(void) = wl.Listener(void).init(handleUnmap),
commit: wl.Listener(*wlr.Surface) = wl.Listener(*wlr.Surface).init(handleCommit),

// XdgTopLevel Listeners
destroy: wl.Listener(void) = wl.Listener(void).init(handleDestroy),
request_resize: wl.Listener(*wlr.XdgToplevel.event.Resize) = wl.Listener(handleRequestResize),
request_move: wl.Listener(*wlr.XdgToplevel.event.Move) = wl.Listener(handleRequestMove),

// Not yet silly
// new_popup: wl.Listener(*wlr.XdgPopup) = wl.Listener(*wlr.XdgPopup).init(handleNewPopup),

pub fn initFromTopLevel(xdg_toplevel: *wlr.XdgToplevel) ?*View {
  const self = gpa.create(View) catch {
    std.log.err("Unable to allocate memory for new XdgTopLevel", .{});
    return null;
  };

  const xdg_surface = xdg_toplevel.base;

  self.* = .{
    .xdg_toplevel = xdg_toplevel,
    .scene_tree = server.root.scene.tree.createSceneXdgSurface(xdg_surface) catch {
      gpa.destroy(self);
      std.log.err("failed to allocate new toplevel", .{});
      return null;
    },
  };

  self.scene_tree.node.data = self;
  xdg_surface.data = self.scene_tree;

  // Attach listeners
  xdg_surface.surface.events.map.add(&self.map);
  xdg_surface.surface.events.unmap.add(&self.unmap);
  xdg_surface.surface.events.commit.add(&self.commit);

  xdg_toplevel.events.destroy.add(&self.destroy);
  xdg_toplevel.events.request_move.add(&self.request_move);
  xdg_toplevel.events.request_resize.add(&self.request_resize);

  // xdg_toplevel.events.request_fullscreen.add(&self.request_fullscreen);
  // xdg_toplevel.events.request_minimize.add(&self.request_minimize);
  // xdg_toplevel.events.request_maxminize.add(&self.request_maximize);

  // xdg_toplevel.events.set_title.add(&self.set_title);
  // xdg_toplevel.events.set_app_id.add(&self.set_app_id);
  // xdg_toplevel.events.set_parent.add(&self.set_parent);

  // xdg_toplevel.events.request_show_window_menu.add(&self.request_show_window_menu);

  return self;
}

pub fn init(xdg_surface: *wlr.XdgSurface) ?*View {
  const self = gpa.create(View) catch {
    std.log.err("Unable to allocate memory for new XdgTopLevel", .{});
    return null;
  };

  if(xdg_surface.role_data.toplevel) |xdg_toplevel| {
    self.xdg_toplevel = xdg_toplevel;
  } else {
    std.log.err("Unable to get top_level from new surface", .{});
    return null;
  }

  self.xdg_toplevel.base.surface.events.map.add(&self.map);
  self.xdg_toplevel.base.surface.events.unmap.add(&self.unmap);
  self.xdg_toplevel.base.surface.events.commit.add(&self.commit);

  self.xdg_toplevel.events.destroy.add(&self.destroy);
  self.xdg_toplevel.events.request_move.add(&self.request_move);
  self.xdg_toplevel.events.request_resize.add(&self.request_resize);
  // self.xdg_toplevel.events.request_move.add(&self.request_move);
  // self.xdg_toplevel.events.request_resize.add(&self.request_resize);

  return self;
}

pub fn deinit(self: *View) void {
  gpa.free(self);
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
    _ = view.xdg_toplevel.setSize(0, 0); // 0,0 means "you decide the size"
  }
}

fn handleNewPopup(listener: *wl.Listener(*wlr.XdgPopup), popup: *wlr.XdgPopup) void {
  _ = listener;
  _ = popup;
  std.log.err("Unimplemented view handle new popup", .{});
}

fn handleRequestResize(listener: *wl.Listener(*wlr.XdgToplevel.event.Resize), resize: *wlr.XdgToplevel.event.Resize) void {
  // const view: *View = @fieldParentPtr("request_resize", listener);
  _ = listener;
  _ = resize;
  std.log.err("Unimplemented view handle resize", .{});
}

fn handleRequestMove(listener: *wl.Listener(*wlr.XdgToplevel.event.Move), move: *wlr.XdgToplevel.event.Move) void {
  // const view: *View = @fieldParentPtr("request_move", listener);
  _ = listener;
  _ = move;
  std.log.err("Unimplemented view handle move", .{});
}
