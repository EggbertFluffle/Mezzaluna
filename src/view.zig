const View = @This();

const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const gpa = std.heap.c_allocator;
const server = &@import("main.zig").server;

xdg_toplevel: *wlr.XdgToplevel,

// XdgTopLevel Listeners
map: wl.Listener(void) = wl.Listener(void).init(handleMap),
unmap: wl.Listener(void) = wl.Listener(void).init(handleUnmap),
commit: wl.Listener(*wlr.Surface) = wl.Listener(*wlr.Surface).init(handleCommit),
destroy: wl.Listener(void) = wl.Listener(void).init(handleDestroy),

// Not yet silly
// new_popup: wl.Listener(*wlr.XdgPopup) = wl.Listener(*wlr.XdgPopup).init(handleNewPopup),

pub fn initFromTopLevel(xdg_toplevel: *wlr.XdgToplevel) ?*View {
  const self = gpa.create(View) catch {
    std.log.err("Unable to allocate memory for new XdgTopLevel", .{});
    return null;
  };

  self.xdg_toplevel = xdg_toplevel;

  self.xdg_toplevel.base.surface.events.map.add(&self.map);
  self.xdg_toplevel.base.surface.events.unmap.add(&self.unmap);
  self.xdg_toplevel.base.surface.events.commit.add(&self.commit);

  self.xdg_toplevel.events.destroy.add(&self.destroy);
  // self.xdg_toplevel.events.request_move.add(&self.request_move);
  // self.xdg_toplevel.events.request_resize.add(&self.request_resize);

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
  server.seat.wlr_seat.keyboardNotifyEnter(xdg_surface.surface, &.{}, null);
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

fn handleCommit(listener: *wl.Listener(*wlr.Surface), surface: *wlr.Surface) void {
  _ = listener;
  _ = surface;
  std.log.err("Unimplemented view handle commit", .{});
}

fn handleNewPopup(listener: *wl.Listener(*wlr.XdgPopup), popup: *wlr.XdgPopup) void {
  _ = listener;
  _ = popup;
  std.log.err("Unimplemented view handle new popup", .{});
}
