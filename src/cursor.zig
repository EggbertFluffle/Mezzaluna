pub const Cursor = @This();

const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const View = @import("view.zig");

const server = &@import("main.zig").server;

wlr_cursor: *wlr.Cursor,
x_cursor_manager: *wlr.XcursorManager,

motion: wl.Listener(*wlr.Pointer.event.Motion) = .init(handleMotion),
motion_absolute: wl.Listener(*wlr.Pointer.event.MotionAbsolute) = .init(handleMotionAbsolute),
button: wl.Listener(*wlr.Pointer.event.Button) = .init(handleButton),
axis: wl.Listener(*wlr.Pointer.event.Axis) = .init(handleAxis),
frame: wl.Listener(*wlr.Cursor) = .init(handleFrame),
hold_begin: wl.Listener(*wlr.Pointer.event.HoldBegin) = .init(handleHoldBegin),
hold_end: wl.Listener(*wlr.Pointer.event.HoldEnd) = .init(handleHoldEnd),

cursor_mode: enum { passthrough, move, resize } = .passthrough,
grabbed_view: ?*View = null,
grab_x: f64 = 0,
grab_y: f64 = 0,
grab_box: wlr.Box = undefined,

pub fn init(self: *Cursor) !void {
  self.* = .{
    .wlr_cursor = try wlr.Cursor.create(),
    .x_cursor_manager = try wlr.XcursorManager.create(null, 24),
  };

  try self.x_cursor_manager.load(1);

  self.wlr_cursor.attachOutputLayout(server.root.output_layout);

  self.wlr_cursor.events.motion.add(&self.motion);
  self.wlr_cursor.events.motion_absolute.add(&self.motion_absolute);
  self.wlr_cursor.events.button.add(&self.button);
  self.wlr_cursor.events.axis.add(&self.axis);
  self.wlr_cursor.events.frame.add(&self.frame);
  self.wlr_cursor.events.hold_begin.add(&self.hold_begin);
  self.wlr_cursor.events.hold_end.add(&self.hold_end);
}

pub fn deinit(self: *Cursor) void {
  self.wlr_cursor.destroy();
  self.x_cursor_manager.destroy();

  self.motion.link.remove();
  self.motion_absolute.link.remove();
  self.button.link.remove();
  self.axis.link.remove();
  self.frame.link.remove();
}

pub fn processCursorMotion(self: *Cursor, time_msec: u32) void {
  if (server.root.viewAt(self.wlr_cursor.x, self.wlr_cursor.y)) |res| {
    std.log.debug("we found a view", .{});
    server.seat.wlr_seat.pointerNotifyEnter(res.surface, res.sx, res.sy);
    server.seat.wlr_seat.pointerNotifyMotion(time_msec, res.sx, res.sy);
  } else {
    std.log.debug("no view found", .{});
    self.wlr_cursor.setXcursor(self.x_cursor_manager, "default");
    server.seat.wlr_seat.pointerClearFocus();
  }
}

// --------- WLR Cursor event handlers ---------
fn handleMotion(
  _: *wl.Listener(*wlr.Pointer.event.Motion),
  event: *wlr.Pointer.event.Motion,
) void {
  server.cursor.wlr_cursor.move(event.device, event.delta_x, event.delta_y);
  server.cursor.processCursorMotion(event.time_msec);
}

fn handleMotionAbsolute(
  _: *wl.Listener(*wlr.Pointer.event.MotionAbsolute),
  event: *wlr.Pointer.event.MotionAbsolute,
) void {
  server.cursor.wlr_cursor.warpAbsolute(event.device, event.x, event.y);
  server.cursor.processCursorMotion(event.time_msec);
}

fn handleButton(
  _: *wl.Listener(*wlr.Pointer.event.Button),
  event: *wlr.Pointer.event.Button,
) void {
  _ = server.seat.wlr_seat.pointerNotifyButton(event.time_msec, event.button, event.state);
  if (server.root.viewAt(server.cursor.wlr_cursor.x, server.cursor.wlr_cursor.y)) |res| {
    server.root.focusView(res.view);
  }
}

fn handleHoldBegin(
  listener: *wl.Listener(*wlr.Pointer.event.HoldBegin),
  event: *wlr.Pointer.event.HoldBegin
) void {
  _ = listener;
  _ = event;
  std.log.err("Unimplemented cursor being hold", .{});
}

fn handleHoldEnd(
  listener: *wl.Listener(*wlr.Pointer.event.HoldEnd),
  event: *wlr.Pointer.event.HoldEnd
) void {
  _ = listener;
  _ = event;
  std.log.err("Unimplemented cursor end hold", .{});
}

fn handleAxis(
  _: *wl.Listener(*wlr.Pointer.event.Axis),
  event: *wlr.Pointer.event.Axis,
) void {
  server.seat.wlr_seat.pointerNotifyAxis(
    event.time_msec,
    event.orientation,
    event.delta,
    event.delta_discrete,
    event.source,
    event.relative_direction,
  );
}

fn handleFrame(_: *wl.Listener(*wlr.Cursor), _: *wlr.Cursor) void {
  server.seat.wlr_seat.pointerNotifyFrame();
}
