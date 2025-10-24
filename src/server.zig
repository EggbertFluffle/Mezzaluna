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
const Utils = @import("utils.zig");
const Keymap = @import("keymap.zig");

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
xdg_toplevel_decoration_manager: *wlr.XdgDecorationManagerV1,

// Input

allocator: *wlr.Allocator,

root: Root,
seat: Seat,
cursor: Cursor,
keyboard: Keyboard,
keymaps: std.AutoHashMap(u64, Keymap),

// Backend listeners
new_input: wl.Listener(*wlr.InputDevice) = .init(handleNewInput),
new_output: wl.Listener(*wlr.Output) = .init(handleNewOutput),
// backend.events.destroy

// XdgShell listeners
new_xdg_toplevel: wl.Listener(*wlr.XdgToplevel) = .init(handleNewXdgToplevel),
new_xdg_popup: wl.Listener(*wlr.XdgPopup) = .init(handleNewXdgPopup),
new_xdg_toplevel_decoration: wl.Listener(*wlr.XdgToplevelDecorationV1) = .init(handleNewXdgToplevelDecoration),
// new_xdg_popup
// new_xdg_toplevel

// Seat listeners

pub fn init(self: *Server) void {
  errdefer Utils.oomPanic();

  const wl_server = wl.Server.create() catch {
    std.log.err("Server create failed, exiting with 2", .{});
    std.process.exit(2);
  };

  const event_loop = wl_server.getEventLoop();

  var session: ?*wlr.Session = undefined;
  const backend = wlr.Backend.autocreate(event_loop, &session) catch {
    std.log.err("Backend create failed, exiting with 3", .{});
    std.process.exit(3);
  };

  const renderer = wlr.Renderer.autocreate(backend) catch {
    std.log.err("Renderer create failed, exiting with 4", .{});
    std.process.exit(4);
  };

  self.* = .{
    .wl_server = wl_server,
    .backend = backend,
    .renderer = renderer,
    .allocator = wlr.Allocator.autocreate(backend, renderer) catch {
      std.log.err("Allocator create failed, exiting with 5", .{});
      std.process.exit(5);
    },
    .xdg_shell = try wlr.XdgShell.create(wl_server, 2),
    .xdg_toplevel_decoration_manager = try wlr.XdgDecorationManagerV1.create(self.wl_server),
    .event_loop = event_loop,
    .session = session,
    .compositor = try wlr.Compositor.create(wl_server, 6, renderer),
    .shm = try wlr.Shm.createWithRenderer(wl_server, 1, renderer),
    // TODO: let the user configure a cursor theme and side lua
    .root = undefined,
    .seat = undefined,
    .cursor = undefined,
    .keyboard = undefined,
    .keymaps = .init(gpa),
  };

  self.renderer.initServer(wl_server) catch {
      std.log.err("Renderer init failed, exiting with 6", .{});
      std.process.exit(6);
  };

  self.root.init();
  self.seat.init();
  self.cursor.init();

  _ = try wlr.Subcompositor.create(self.wl_server);
  _ = try wlr.DataDeviceManager.create(self.wl_server);

  // Add event listeners to events
  // Backedn events
  self.backend.events.new_input.add(&self.new_input);
  self.backend.events.new_output.add(&self.new_output);

  // XdgShell events
  self.xdg_shell.events.new_toplevel.add(&self.new_xdg_toplevel);
  self.xdg_shell.events.new_popup.add(&self.new_xdg_popup);

  // XdgDecorationManagerV1 events
  // self.xdg_toplevel_decoration_manager.events.new_toplevel_decoration.add(&self.new_toplevel_decoration);
}

pub fn deinit(self: *Server) void {
  self.new_input.link.remove();
  self.new_output.link.remove();
  self.new_xdg_toplevel.link.remove();
  self.new_xdg_popup.link.remove();
  self.new_xdg_toplevel.link.remove();

  self.seat.deinit();
  self.root.deinit();
  self.cursor.deinit();

  self.backend.destroy();

  self.wl_server.destroyClients();
  self.wl_server.destroy();
}

// --------- Backend event handlers ---------
fn handleNewInput(
  _: *wl.Listener(*wlr.InputDevice),
  device: *wlr.InputDevice
) void {
  switch (device.type) {
    .keyboard => server.keyboard.init(device),
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

  const new_output = Output.create(wlr_output);

  server.root.addOutput(new_output);
}

fn handleNewXdgToplevel(
  _: *wl.Listener(*wlr.XdgToplevel),
  xdg_toplevel: *wlr.XdgToplevel
) void {
  _ = View.initFromTopLevel(xdg_toplevel);
}

fn handleNewXdgPopup(
  _: *wl.Listener(*wlr.XdgPopup),
  _: *wlr.XdgPopup
) void {
  std.log.err("Unimplemented handle new xdg popup", .{});
}

fn handleNewXdgToplevelDecoration(
  _: *wl.Listener(*wlr.XdgToplevelDecorationV1),
  decoration: *wlr.XdgToplevelDecorationV1
) void {
  // TODO: Configured with lua perhaps
  decoration.current.mode = .server_side;
}
