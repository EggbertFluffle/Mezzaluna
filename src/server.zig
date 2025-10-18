const Server = @This();

const std = @import("std");
const gpa = std.heap.c_allocator;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Output = @import("output.zig");
const Keyboard = @import("keyboard.zig");

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

// Input things
seat: *wlr.Seat,
keyboards: wl.list.Head(Keyboard, .link) = undefined,

// Listeners
new_output: wl.Listener(*wlr.Output) = .init(newOutput),
new_input: wl.Listener(*wlr.InputDevice) = .init(newInput),

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
  };

  try server.renderer.initServer(wl_server);

  server.backend.events.new_output.add(&server.new_output);
  server.backend.events.new_input.add(&server.new_input);

  server.keyboards.init();
}

pub fn deinit(server: *Server) void {
  server.wl_server.destroyClients();

  server.new_input.link.remove();
  server.new_output.link.remove();

  server.backend.destroy();
  server.wl_server.destroy();
}

fn newOutput(listener: *wl.Listener(*wlr.Output), wlr_output: *wlr.Output) void {
  const server: *Server = @fieldParentPtr("new_output", listener);

  if (!wlr_output.initRender(server.allocator, server.renderer)) return;

  var state = wlr.Output.State.init();
  defer state.finish();

  state.setEnabled(true);
  if (wlr_output.preferredMode()) |mode| {
    state.setMode(mode);
  }
  if (!wlr_output.commitState(&state)) return;

  Output.create(server, wlr_output) catch {
    std.log.err("failed to allocate new output", .{});
    wlr_output.destroy();
    return;
  };
}

fn newInput(listener: *wl.Listener(*wlr.InputDevice), device: *wlr.InputDevice) void {
  const server: *Server = @fieldParentPtr("new_input", listener);
  switch (device.type) {
    .keyboard => Keyboard.create(server, device) catch |err| {
      std.log.err("failed to create keyboard: {}", .{err});
      return;
    },
    // TODO: impl cursor
    // .pointer => server.cursor.attachInputDevice(device),
    else => {},
  }

  server.seat.setCapabilities(.{
    .pointer = true,
    .keyboard = server.keyboards.length() > 0,
  });
}
