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

// Drag information
drag_start_x: c_int = 0,
drag_start_y: c_int = 0,
drag_view_offset_x: c_int = 0,
drag_view_offset_y: c_int = 0,
drag_view_width: c_int = 0,
drag_view_height: c_int = 0,

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
  self.motion.link.remove();
  self.motion_absolute.link.remove();
  self.button.link.remove();
  self.axis.link.remove();
  self.frame.link.remove();
  self.hold_begin.link.remove();
  self.hold_end.link.remove();

  self.wlr_cursor.destroy();
  self.x_cursor_manager.destroy();
}

pub fn processCursorMotion(self: *Cursor, time_msec: u32) void {
  switch (self.mode) {
    .passthrough => {
      if (server.root.viewAt(self.wlr_cursor.x, self.wlr_cursor.y)) |res| {
        res.view.setFocused();

        server.seat.wlr_seat.pointerNotifyEnter(res.surface, res.sx, res.sy);
        server.seat.wlr_seat.pointerNotifyMotion(time_msec, res.sx, res.sy);
      } else {
        self.wlr_cursor.setXcursor(self.x_cursor_manager, "default");
        server.seat.wlr_seat.pointerClearFocus();
      }
    },
    .move => {
      const focused_view = server.seat.focused_view;

      if(focused_view) |view| {
        view.scene_tree.node.setPosition(
          // TODO: add a lua option to configure the behavior of this, by
          // default it will be the following:
          @as(c_int, @intFromFloat(self.wlr_cursor.x)) - self.drag_view_offset_x,
          @as(c_int, @intFromFloat(self.wlr_cursor.y)) - self.drag_view_offset_y
          // and the user should be able to configure if it clamps or not
        );
      }
    },
    .resize => {
      // Fix this resize
      const focused_view = server.seat.focused_view;

      if(focused_view) |view| {
        _ = view.xdg_toplevel.setSize(
          // TODO: configure the min and max using lua?
          std.math.clamp(@as(c_int, @as(i32, @intFromFloat(self.wlr_cursor.x)) - view.scene_tree.node.x), 10, std.math.maxInt(i32)),
          std.math.clamp(@as(c_int, @as(i32, @intFromFloat(self.wlr_cursor.y)) - view.scene_tree.node.y), 10, std.math.maxInt(i32))
        );
      }
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

  if (server.seat.focused_view) |view| {
    view.setFocused();
  }

  switch (event.state) {
    .pressed => {
      if(server.seat.keyboard_group.keyboard.getModifiers().alt) {
        // Can be BTN_RIGHT, BTN_LEFT, or BTN_MIDDLE
        if(server.seat.focused_view) |view| {
          // Keep track of where the drag started
          cursor.drag_start_x = @as(c_int, @intFromFloat(cursor.wlr_cursor.x));
          cursor.drag_start_y = @as(c_int, @intFromFloat(cursor.wlr_cursor.y));
          cursor.drag_view_offset_x = cursor.drag_start_x - view.scene_tree.node.x;
          cursor.drag_view_offset_y = cursor.drag_start_y - view.scene_tree.node.y;
          cursor.drag_view_width = view.xdg_toplevel.base.geometry.width;
          cursor.drag_view_height = view.xdg_toplevel.base.geometry.height;

          // Maybe comptime this for later reference
          if(event.button == c.libevdev_event_code_from_name(c.EV_KEY, "BTN_LEFT")) {
            cursor.mode = .move;
          } else if(event.button == c.libevdev_event_code_from_name(c.EV_KEY, "BTN_RIGHT")) {
            cursor.mode = .resize;
            _ = view.xdg_toplevel.setResizing(true);
          }
        }
      }
    },
    .released => {
      cursor.mode = .passthrough;

      if(server.seat.focused_view) |view| {
        _ = view.xdg_toplevel.setResizing(false);
      }
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
