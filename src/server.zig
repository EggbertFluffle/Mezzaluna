const Server = @This();

const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Root = @import("root.zig");
const Seat = @import("seat.zig");
const Cursor = @import("cursor.zig");
const Keyboard = @import("keyboard.zig");
const Output = @import("output.zig");
const View = @import("view.zig");

const gpa = std.heap.c_allocator;
const server = &@import("main.zig").server;

wl_server: *wl.Server,
compositor: *wlr.Compositor,
renderer: *wlr.Renderer,
backend: *wlr.Backend,
event_loop: *wl.EventLoop,
session: ?*wlr.Session,

shm: *wlr.Shm,
xdg_shell: *wlr.XdgShell,

// Input

allocator: *wlr.Allocator,

root: Root,
seat: Seat,
cursor: Cursor,
keyboard: Keyboard,

// Backend listeners
new_input: wl.Listener(*wlr.InputDevice) = .init(handleNewInput),
new_output: wl.Listener(*wlr.Output) = .init(handleNewOutput),
// backend.events.destroy

// XdgShell listeners
new_xdg_surface: wl.Listener(*wlr.XdgSurface) = .init(handleNewXdgSurface),
// new_xdg_popup
// new_xdg_toplevel

// Seat listeners

pub fn init(self: *Server) !void {
  const wl_server = try wl.Server.create();
  const event_loop = wl_server.getEventLoop();

  var session: ?*wlr.Session = undefined;
  const backend = try wlr.Backend.autocreate(event_loop, &session);
  const renderer = try wlr.Renderer.autocreate(backend);

  self.* = .{
    .wl_server = wl_server,
    .backend = backend,
    .renderer = renderer,
    .allocator = try wlr.Allocator.autocreate(backend, renderer),
    .xdg_shell = try wlr.XdgShell.create(wl_server, 2),
    .event_loop = event_loop,
    .session = session,
    .compositor = try wlr.Compositor.create(wl_server, 6, renderer),
    .shm = try wlr.Shm.createWithRenderer(wl_server, 1, renderer),
    // TODO: let the user configure a cursor theme and side lua
    .root = undefined,
    .seat = undefined,
    .cursor = undefined,
    .keyboard = undefined,
  };

  try self.renderer.initServer(wl_server);

  try self.root.init();
  try self.seat.init();
  try self.cursor.init();

  _ = try wlr.Subcompositor.create(self.wl_server);
  _ = try wlr.DataDeviceManager.create(self.wl_server);

  // Add event listeners to events
  // Backedn events
  self.backend.events.new_input.add(&self.new_input);
  self.backend.events.new_output.add(&self.new_output);

  // XdgShell events
  self.xdg_shell.events.new_surface.add(&self.new_xdg_surface);

}

pub fn deinit(self: *Server) void {
  self.seat.deinit();
  self.root.deinit();
  self.cursor.deinit();

  self.new_input.link.remove();
  self.new_output.link.remove();

  self.wl_server.destroyClients();

  self.backend.destroy();
  self.wl_server.destroy();
}

// --------- Backend event handlers ---------
fn handleNewInput(
  _: *wl.Listener(*wlr.InputDevice),
  device: *wlr.InputDevice
) void {
  switch (device.type) {
    .keyboard => server.keyboard.init(device) catch {
      std.log.err("Unable to create keyboard from device {s}", .{device.name orelse "(null)"});
    },
    .pointer => server.cursor.wlr_cursor.attachInputDevice(device),
    else => {
      std.log.err(
        "New input request for input that is not a keyboard or pointer: {s}",
        .{device.name orelse "(null)"}
      );
    },
  }

  server.seat.wlr_seat.setCapabilities(.{
    .pointer = true,
    .keyboard = server.keyboard.keyboards.length() > 0,
  });
}

fn handleNewOutput(
  _: *wl.Listener(*wlr.Output),
  wlr_output: *wlr.Output
) void {
  std.log.info("Handling a new output - {s}", .{wlr_output.name});

  if (!wlr_output.initRender(server.allocator, server.renderer)) return;

  var state = wlr.Output.State.init();
  defer state.finish();

  state.setEnabled(true);

  if (wlr_output.preferredMode()) |mode| {
    state.setMode(mode);
  }
  if (!wlr_output.commitState(&state)) return;

  const new_output = Output.create(wlr_output) catch {
    std.log.err("failed to allocate new output", .{});
    wlr_output.destroy();
    return;
  };

  server.root.addOutput(new_output);
}


fn handleRequestSetSelection(
  _: *wl.Listener(*wlr.Seat.event.RequestSetSelection),
  event: *wlr.Seat.event.RequestSetSelection,
) void {
  server.seat.setSelection(event.source, event.serial);
}

fn handleNewXdgSurface(
  _: *wl.Listener(*wlr.XdgSurface),
  xdg_surface: *wlr.XdgSurface
) void {
  std.log.info("New xdg_toplevel added", .{});

  const view = View.init(xdg_surface) catch {
    std.log.err("Unable to allocate a top level", .{});
    return;
  };

  server.root.addView(view);
}
