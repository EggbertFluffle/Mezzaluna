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

mode: enum { passthrough, move, resize } = .passthrough,
grabbed_view: ?*View = null,
grab_x: f64 = 0,
grab_y: f64 = 0,
grab_box: wlr.Box = undefined,
resize_edges: wlr.Edges = .{},

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
  switch (self.mode) {
    .passthrough => {
      if (server.root.viewAt(self.wlr_cursor.x, self.wlr_cursor.y)) |res| {
        server.seat.wlr_seat.pointerNotifyEnter(res.surface, res.sx, res.sy);
        server.seat.wlr_seat.pointerNotifyMotion(time_msec, res.sx, res.sy);
      } else {
        self.wlr_cursor.setXcursor(self.x_cursor_manager, "default");
        server.seat.wlr_seat.pointerClearFocus();
      }
    },
    .move => {
      const view = self.grabbed_view.?;
      // Should we modify the XdgSurface geometry directly???
      view.geometry.x = @as(i32, @intFromFloat(self.wlr_cursor.x - self.grab_x));
      view.geometry.y = @as(i32, @intFromFloat(self.wlr_cursor.y - self.grab_y));
      view.scene_tree.node.setPosition(view.geometry.x, view.geometry.y);
    },
    .resize => {
      // Fix this resize
      const view = self.grabbed_view.?;
      const border_x = @as(i32, @intFromFloat(self.wlr_cursor.x - self.grab_x));
      const border_y = @as(i32, @intFromFloat(self.wlr_cursor.y - self.grab_y));

      var new_left = self.grab_box.x;
      var new_right = self.grab_box.x + self.grab_box.width;
      var new_top = self.grab_box.y;
      var new_bottom = self.grab_box.y + self.grab_box.height;

      if (self.resize_edges.top) {
        new_top = border_y;
        if (new_top >= new_bottom)
        new_top = new_bottom - 1;
      } else if (self.resize_edges.bottom) {
        new_bottom = border_y;
        if (new_bottom <= new_top)
        new_bottom = new_top + 1;
      }

      if (self.resize_edges.left) {
        new_left = border_x;
        if (new_left >= new_right)
        new_left = new_right - 1;
      } else if (self.resize_edges.right) {
        new_right = border_x;
        if (new_right <= new_left)
        new_right = new_left + 1;
      }

      // view.x = new_left - view.xdg_toplevel.base.geometry.x;
      // view.y = new_top - view.xdg_toplevel.base.geometry.y;
      view.scene_tree.node.setPosition(view.geometry.x, view.geometry.y);

      const new_width = new_right - new_left;
      const new_height = new_bottom - new_top;
      _ = view.xdg_toplevel.setSize(new_width, new_height);
    },
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
  switch (event.state) {
    .pressed => {
      _ = server.seat.wlr_seat.pointerNotifyButton(event.time_msec, event.button, event.state);
      if (server.root.viewAt(server.cursor.wlr_cursor.x, server.cursor.wlr_cursor.y)) |res| {
        server.root.focusView(res.view);
      }
    },
    .released => {
      std.log.debug("Button released", .{});
      server.cursor.mode = .passthrough;
    },
    else => {
      std.log.err("Unexpected button state", .{});
    }
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
