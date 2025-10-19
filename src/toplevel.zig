const TopLevel = @This();

const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const gpa = std.heap.c_allocator;
const server = &@import("main.zig").server;

xdg_toplevel: *wlr.XdgToplevel,
box: *wlr.Box,

pub fn init(xdg_surface: *wlr.XdgSurface) !*TopLevel {
  const top_level = gpa.create(TopLevel) catch |err| {
    std.log.err("Unable to allocate memory for new XdgTopLevel", .{});
    return err;
  };

  if(xdg_surface.role_data.toplevel) |xgd_toplevel| {
    top_level.* = .{
      .xdg_toplevel = xgd_toplevel,
      .box = undefined,
    };

    top_level.box.x = 0;
    top_level.box.y = 0;
    top_level.box.width = 640;
    top_level.box.height = 360;
  }

  // Listen to important toplevel events
  // top_level.xdg_toplevel.events.set_title.add(listener: *Listener(void))

  return top_level;
}
