//! Maintains state related to cursor position, rendering, and
//! events such as button presses and dragging

pub const Cursor = @This();

const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");
const xkb = @import("xkbcommon");

const View = @import("view.zig");
const Utils = @import("utils.zig");

const c = @import("c.zig").c;

const server = &@import("main.zig").server;
const linux = std.os.linux;

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
selected_view: ?*View = null,
grab_box: wlr.Box = undefined,

pub fn init(self: *Cursor) void {
  errdefer Utils.oomPanic();

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

pub fn moveView(self: *Cursor, view: *View, _: *wlr.Pointer.event.Button) void {
  self.mode = .move;
  self.selected_view = view;
}

pub fn resizeView(self: *Cursor, view: *View, _: *wlr.Pointer.event.Button) void {
  self.mode = .resize;
  self.selected_view = view;
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
      const view = self.selected_view.?;
      view.scene_tree.node.setPosition(
        @as(i32, @intFromFloat(self.wlr_cursor.x)),
        @as(i32, @intFromFloat(self.wlr_cursor.y))
      );
    },
    .resize => {
      // Fix this resize
      //
      // REDOING RESIZING AND MOVING TOPLEVELS
      // REDOING RESIZING AND MOVING TOPLEVELS
      // REDOING RESIZING AND MOVING TOPLEVELS
      // REDOING RESIZING AND MOVING TOPLEVELS
      //
      // const view = self.grabbed_view.?;
      // const border_x = @as(i32, @intFromFloat(self.wlr_cursor.x - self.grab_x));
      // const border_y = @as(i32, @intFromFloat(self.wlr_cursor.y - self.grab_y));
      //
      // var new_left = self.grab_box.x;
      // var new_right = self.grab_box.x + self.grab_box.width;
      // var new_top = self.grab_box.y;
      // var new_bottom = self.grab_box.y + self.grab_box.height;
      //
      // if (self.resize_edges.top) {
      //   new_top = border_y;
      //   if (new_top >= new_bottom)
      //   new_top = new_bottom - 1;
      // } else if (self.resize_edges.bottom) {
      //   new_bottom = border_y;
      //   if (new_bottom <= new_top)
      //   new_bottom = new_top + 1;
      // }
      //
      // if (self.resize_edges.left) {
      //   new_left = border_x;
      //   if (new_left >= new_right)
      //   new_left = new_right - 1;
      // } else if (self.resize_edges.right) {
      //   new_right = border_x;
      //   if (new_right <= new_left)
      //   new_right = new_left + 1;
      // }
      //
      // // view.x = new_left - view.xdg_toplevel.base.geometry.x;
      // // view.y = new_top - view.xdg_toplevel.base.geometry.y;
      // view.scene_tree.node.setPosition(view.geometry.x, view.geometry.y);
      //
      // const new_width = new_right - new_left;
      // const new_height = new_bottom - new_top;
      // _ = view.xdg_toplevel.setSize(new_width, new_height);
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
  listener: *wl.Listener(*wlr.Pointer.event.Button),
  event: *wlr.Pointer.event.Button
) void {
  const cursor: *Cursor = @fieldParentPtr("button", listener);

  _ = server.seat.wlr_seat.pointerNotifyButton(event.time_msec, event.button, event.state);

  const view_at_result = server.root.viewAt(cursor.wlr_cursor.x, cursor.wlr_cursor.y);
  if (view_at_result) |res| {
    server.root.focusView(res.view);
  }

  std.log.debug("Button pressed {}", .{event.button});

  switch (event.state) {
    .pressed => {
      if(server.keyboard.wlr_keyboard.getModifiers().alt) {
        // Can be BTN_RIGHT, BTN_LEFT, or BTN_MIDDLE
        if(view_at_result) |res| {
          if(event.button == c.libevdev_event_code_from_name(c.EV_KEY, "BTN_LEFT")) {
            cursor.moveView(res.view, event);
          } else if(event.button == c.libevdev_event_code_from_name(c.EV_KEY, "BTN_RIGHT")) {
            cursor.resizeView(res.view, event);
          }
        }
      }
    },
    .released => {
      cursor.mode = .passthrough;
    },
    else => {
      std.log.err("Invalid/Unimplemented pointer button event type", .{});
    }
  }
}

fn handleHoldBegin(
  listener: *wl.Listener(*wlr.Pointer.event.HoldBegin),
  event: *wlr.Pointer.event.HoldBegin
) void {
  _ = listener;
  _ = event;
  std.log.err("Unimplemented cursor start hold", .{});
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
