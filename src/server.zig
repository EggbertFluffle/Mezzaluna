const Server = @This();

const std = @import("std");
const gpa = std.heap.c_allocator;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Output = @import("output.zig");
const Keyboard = @import("keyboard.zig");
const Root = @import("root.zig").Root;

allocator: *wlr.Allocator,
backend: *wlr.Backend,
compositor: *wlr.Compositor,
event_loop: *wl.EventLoop,
output_layout: *wlr.OutputLayout,
renderer: *wlr.Renderer,
scene: *wlr.Scene,
scene_output_layout: *wlr.SceneOutputLayout,
session: ?*wlr.Session,
shm: *wlr.Shm,
wl_server: *wl.Server,
xdg_shell: *wlr.XdgShell,
root: Root,

// Input things
seat: *wlr.Seat,
keyboards: wl.list.Head(Keyboard, .link) = undefined,
cursor: *wlr.Cursor,
cursor_mgr: *wlr.XcursorManager,

// Listeners
new_input: wl.Listener(*wlr.InputDevice) = .init(newInput),
cursor_motion: wl.Listener(*wlr.Pointer.event.Motion) = .init(cursorMotion),
cursor_motion_absolute: wl.Listener(*wlr.Pointer.event.MotionAbsolute) = .init(cursorMotionAbsolute),
cursor_button: wl.Listener(*wlr.Pointer.event.Button) = .init(cursorButton),
cursor_axis: wl.Listener(*wlr.Pointer.event.Axis) = .init(cursorAxis),
cursor_frame: wl.Listener(*wlr.Cursor) = .init(cursorFrame),
request_set_cursor: wl.Listener(*wlr.Seat.event.RequestSetCursor) = .init(requestSetCursor),
request_set_selection: wl.Listener(*wlr.Seat.event.RequestSetSelection) = .init(requestSetSelection),

pub fn init(server: *Server) !void {
  const wl_server = try wl.Server.create();
  const event_loop = wl_server.getEventLoop();

  var session: ?*wlr.Session = undefined;
  const backend = try wlr.Backend.autocreate(event_loop, &session);
  const renderer = try wlr.Renderer.autocreate(backend);
  const output_layout = try wlr.OutputLayout.create(wl_server);
  const scene = try wlr.Scene.create();

  // Do we need to fail if session is NULL

  server.* = .{
    .wl_server = wl_server,
    .backend = backend,
    .renderer = renderer,
    .allocator = try wlr.Allocator.autocreate(backend, renderer),
    .scene = scene,
    .output_layout = output_layout,
    .scene_output_layout = try scene.attachOutputLayout(output_layout),
    .xdg_shell = try wlr.XdgShell.create(wl_server, 2),
    .event_loop = event_loop,
    .session = session,
    .compositor = try wlr.Compositor.create(wl_server, 6, renderer),
    .shm = try wlr.Shm.createWithRenderer(wl_server, 1, renderer),
    .seat = try wlr.Seat.create(wl_server, "default"),
    .cursor = try wlr.Cursor.create(),
    // TODO: let the user configure a cursor theme and side lua
    .cursor_mgr = try wlr.XcursorManager.create(null, 24),
    .root = undefined,
  };

  try server.renderer.initServer(wl_server);
  try Root.init(&server.root);

  server.backend.events.new_input.add(&server.new_input);
  server.seat.events.request_set_cursor.add(&server.request_set_cursor);
  server.seat.events.request_set_selection.add(&server.request_set_selection);
  server.keyboards.init();

  server.cursor.attachOutputLayout(server.output_layout);
  try server.cursor_mgr.load(1);
  server.cursor.events.motion.add(&server.cursor_motion);
  server.cursor.events.motion_absolute.add(&server.cursor_motion_absolute);
  server.cursor.events.button.add(&server.cursor_button);
  server.cursor.events.axis.add(&server.cursor_axis);
  server.cursor.events.frame.add(&server.cursor_frame);
}

pub fn deinit(server: *Server) void {
  server.wl_server.destroyClients();

  server.cursor.destroy();
  server.cursor_mgr.destroy();

  server.new_input.link.remove();
  server.cursor_motion.link.remove();
  server.cursor_motion_absolute.link.remove();
  server.cursor_button.link.remove();
  server.cursor_axis.link.remove();
  server.cursor_frame.link.remove();
  server.request_set_cursor.link.remove();
  server.request_set_selection.link.remove();

  server.backend.destroy();
  server.seat.destroy();
  server.wl_server.destroy();
}

fn newInput(listener: *wl.Listener(*wlr.InputDevice), device: *wlr.InputDevice) void {
  const server: *Server = @fieldParentPtr("new_input", listener);
  switch (device.type) {
    .keyboard => Keyboard.create(server, device) catch |err| {
      std.log.err("failed to create keyboard: {}", .{err});
      return;
    },
    .pointer => server.cursor.attachInputDevice(device),
    else => {},
  }

  server.seat.setCapabilities(.{
    .pointer = true,
    .keyboard = server.keyboards.length() > 0,
  });
}

fn cursorMotion(
  listener: *wl.Listener(*wlr.Pointer.event.Motion),
  event: *wlr.Pointer.event.Motion,
) void {
  const server: *Server = @fieldParentPtr("cursor_motion", listener);
  server.cursor.move(event.device, event.delta_x, event.delta_y);
  server.processCursorMotion(event.time_msec);
}

fn cursorMotionAbsolute(
  listener: *wl.Listener(*wlr.Pointer.event.MotionAbsolute),
  event: *wlr.Pointer.event.MotionAbsolute,
) void {
  const server: *Server = @fieldParentPtr("cursor_motion_absolute", listener);
  server.cursor.warpAbsolute(event.device, event.x, event.y);
  server.processCursorMotion(event.time_msec);
}

fn processCursorMotion(server: *Server, time_msec: u32) void {
  if (server.viewAt(server.cursor.x, server.cursor.y)) |res| {
    server.seat.pointerNotifyEnter(res.surface, res.sx, res.sy);
    server.seat.pointerNotifyMotion(time_msec, res.sx, res.sy);
  } else {
    server.cursor.setXcursor(server.cursor_mgr, "default");
    server.seat.pointerClearFocus();
  }
}

const ViewAtResult = struct {
  // TODO: uncomment when we have toplevels
  // toplevel: *Toplevel,
  surface: *wlr.Surface,
  sx: f64,
  sy: f64,
};

fn viewAt(server: *Server, lx: f64, ly: f64) ?ViewAtResult {
  var sx: f64 = undefined;
  var sy: f64 = undefined;
  if (server.scene.tree.node.at(lx, ly, &sx, &sy)) |node| {
    if (node.type != .buffer) return null;
    // TODO: uncomment when we have toplevels
    // const scene_buffer = wlr.SceneBuffer.fromNode(node);
    // const scene_surface = wlr.SceneSurface.tryFromBuffer(scene_buffer) orelse return null;

    var it: ?*wlr.SceneTree = node.parent;
    while (it) |n| : (it = n.node.parent) {
      // if (@as(?*Toplevel, @ptrCast(@alignCast(n.node.data)))) |toplevel| {
      //   return ViewAtResult{
      //     .toplevel = toplevel,
      //     .surface = scene_surface.surface,
      //     .sx = sx,
      //     .sy = sy,
      //   };
      // }
    }
  }
  return null;
}

fn cursorButton(
  listener: *wl.Listener(*wlr.Pointer.event.Button),
  event: *wlr.Pointer.event.Button,
) void {
  const server: *Server = @fieldParentPtr("cursor_button", listener);
  _ = server.seat.pointerNotifyButton(event.time_msec, event.button, event.state);
  // TODO: figure out what this listener is supposed to do

  // if (event.state == .released) {
  //   server.cursor_mode = .passthrough;
  // } else if (server.viewAt(server.cursor.x, server.cursor.y)) |res| {
  //   server.focusView(res.toplevel, res.surface);
  // }
}

fn cursorAxis(
  listener: *wl.Listener(*wlr.Pointer.event.Axis),
  event: *wlr.Pointer.event.Axis,
) void {
  const server: *Server = @fieldParentPtr("cursor_axis", listener);
  server.seat.pointerNotifyAxis(
    event.time_msec,
    event.orientation,
    event.delta,
    event.delta_discrete,
    event.source,
    event.relative_direction,
  );
}

fn cursorFrame(listener: *wl.Listener(*wlr.Cursor), _: *wlr.Cursor) void {
  const server: *Server = @fieldParentPtr("cursor_frame", listener);
  server.seat.pointerNotifyFrame();
}

fn requestSetCursor(
  listener: *wl.Listener(*wlr.Seat.event.RequestSetCursor),
  event: *wlr.Seat.event.RequestSetCursor,
) void {
  const server: *Server = @fieldParentPtr("request_set_cursor", listener);
  if (event.seat_client == server.seat.pointer_state.focused_client)
    server.cursor.setSurface(event.surface, event.hotspot_x, event.hotspot_y);
}

fn requestSetSelection(
  listener: *wl.Listener(*wlr.Seat.event.RequestSetSelection),
  event: *wlr.Seat.event.RequestSetSelection,
) void {
  const server: *Server = @fieldParentPtr("request_set_selection", listener);
  server.seat.setSelection(event.source, event.serial);
}
