const Seat = @This();

const std = @import("std");
const server = &@import("main.zig").server;

const wlr = @import("wlroots");
const wl = @import("wayland").server.wl;

wlr_seat: *wlr.Seat,

request_set_cursor: wl.Listener(*wlr.Seat.event.RequestSetCursor) = .init(handleRequestSetCursor),
request_set_selection: wl.Listener(*wlr.Seat.event.RequestSetSelection) = .init(handleRequestSetSelection),
// request_set_primary_selection
// request_start_drage

pub fn init(self: *Seat) !void {
  self.* = .{
    .wlr_seat = try wlr.Seat.create(server.wl_server, "default"),
  };

  self.wlr_seat.events.request_set_cursor.add(&self.request_set_cursor);
  self.wlr_seat.events.request_set_selection.add(&self.request_set_selection);
}

pub fn deinit(self: *Seat) void {
  self.wlr_seat.destroy();

  self.request_set_cursor.link.remove();
  self.request_set_selection.link.remove();
}

fn handleRequestSetCursor(
  _: *wl.Listener(*wlr.Seat.event.RequestSetCursor),
  event: *wlr.Seat.event.RequestSetCursor,
) void {
  if (event.seat_client == server.seat.wlr_seat.pointer_state.focused_client)
  server.cursor.wlr_cursor.setSurface(event.surface, event.hotspot_x, event.hotspot_y);
}

fn handleRequestSetSelection (
  _: *wl.Listener(*wlr.Seat.event.RequestSetSelection),
  event: *wlr.Seat.event.RequestSetSelection,
) void {
  server.seat.wlr_seat.setSelection(event.source, event.serial);
}
