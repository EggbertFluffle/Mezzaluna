const View = @This();

const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const gpa = std.heap.c_allocator;
const server = &@import("main.zig").server;

xdg_toplevel: *wlr.XdgToplevel,
box: *wlr.Box,

// Listeners
destroy: wl.Listener(void) = wl.Listener(void).init(handleDestroy),
map: wl.Listener(void) = wl.Listener(void).init(handleMap),
unmap: wl.Listener(void) = wl.Listener(void).init(handleUnmap),
commit: wl.Listener(*wlr.Surface) = wl.Listener(*wlr.Surface).init(handleCommit),
new_popup: wl.Listener(*wlr.XdgPopup) = wl.Listener(*wlr.XdgPopup).init(handleNewPopup),

pub fn init(xdg_surface: *wlr.XdgSurface) !*View {
  const view = gpa.create(View) catch |err| {
    std.log.err("Unable to allocate memory for new XdgTopLevel", .{});
    return err;
  };

  if(xdg_surface.role_data.toplevel) |xgd_toplevel| {
    view.* = .{
      .xdg_toplevel = xgd_toplevel,
      .box = undefined,
    };

    view.box.x = 0;
    view.box.y = 0;
  }

  return view;
}

// --------- XdgTopLevel event handlers ---------
fn handleMap(listener: *wl.Listener(void)) void {
  _ = listener;
  std.log.err("Unimplemented view handle map", .{});
}

fn handleUnmap(listener: *wl.Listener(void)) void {
  _ = listener;
  std.log.err("Unimplemented view handle unamp", .{});
}

fn handleDestroy(listener: *wl.Listener(void)) void {
  _ = listener;
  std.log.err("Unimplemented view handle destroy", .{});
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
