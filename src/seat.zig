const Seat = @This();

const std = @import("std");
const wlr = @import("wlroots");
const wl = @import("wayland").server.wl;
const xkb = @import("xkbcommon");

const Utils = @import("utils.zig");
const View = @import("view.zig");
const Output = @import("output.zig");

const server = &@import("main.zig").server;

wlr_seat: *wlr.Seat,
focused_view: ?*View,
focused_output: ?*Output,

keyboard_group: *wlr.KeyboardGroup,
keymap: *xkb.Keymap,

request_set_cursor: wl.Listener(*wlr.Seat.event.RequestSetCursor) = .init(handleRequestSetCursor),
request_set_selection: wl.Listener(*wlr.Seat.event.RequestSetSelection) = .init(handleRequestSetSelection),
// request_set_primary_selection
// request_start_drage

pub fn init(self: *Seat) void {
  errdefer Utils.oomPanic();

  const xkb_context = xkb.Context.new(.no_flags) orelse {
    std.log.err("Unable to create a xkb context, exiting", .{});
    std.process.exit(7);
  };
  defer xkb_context.unref();

  const keymap = xkb.Keymap.newFromNames(xkb_context, null, .no_flags) orelse {
    std.log.err("Unable to create a xkb keymap, exiting", .{});
    std.process.exit(8);
  };
  defer keymap.unref();

  self.* = .{
    .wlr_seat = try wlr.Seat.create(server.wl_server, "default"),
    .focused_view = null,
    .focused_output = null,
    .keyboard_group = try wlr.KeyboardGroup.create(),
    .keymap = keymap.ref(),
  };
  errdefer {
    self.keyboard_group.destroy();
    self.wlr_seat.destroy();
  }

  _ = self.keyboard_group.keyboard.setKeymap(self.keymap);
  self.wlr_seat.setKeyboard(&self.keyboard_group.keyboard);

  self.wlr_seat.events.request_set_cursor.add(&self.request_set_cursor);
  self.wlr_seat.events.request_set_selection.add(&self.request_set_selection);
}

pub fn deinit(self: *Seat) void {
  self.request_set_cursor.link.remove();
  self.request_set_selection.link.remove();

  self.keyboard_group.destroy();
  self.wlr_seat.destroy();
}

pub fn focusOutput(self: *Seat, output: *Output) void {
  if(self.focused_output) |prev_output| {
    prev_output.focused = false;
  }

  self.focused_output = output;
}

// TODO: Should focusing a view, automaticall focus the output containing it
pub fn focusView(self: *Seat, view: *View) void {
  if(self.focused_view) |prev_view| {
    prev_view.setFocus(false);
  }

  self.focused_view = view;
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
