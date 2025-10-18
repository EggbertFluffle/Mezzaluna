const std = @import("std");
const gpa = std.heap.c_allocator;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Output = @import("output.zig").Output;
const Root = @import("root.zig").Root;

pub const Server = struct {
  allocator: *wlr.Allocator,

  wl_server: *wl.Server,
  event_loop: *wl.EventLoop,
  shm: *wlr.Shm,
  scene: *wlr.Scene,
  output_layout: *wlr.OutputLayout,
  xdg_shell: *wlr.XdgShell,
  seat: *wlr.Seat,

  session: ?*wlr.Session,
  backend: *wlr.Backend,
  renderer: *wlr.Renderer,

  compositor: *wlr.Compositor,

  root: Root,

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
      .xdg_shell = try wlr.XdgShell.create(wl_server, 2),
      .event_loop = event_loop,
      .session = session,
      .compositor = try wlr.Compositor.create(wl_server, 6, renderer),
      .shm = try wlr.Shm.createWithRenderer(wl_server, 1, renderer),
      .seat = try wlr.Seat.create(wl_server, "default"),

      .root = undefined,
    };

    try server.renderer.initServer(wl_server);

    _ = try wlr.Compositor.create(server.wl_server, 6, server.renderer);
    _ = try wlr.Subcompositor.create(server.wl_server);
    _ = try wlr.DataDeviceManager.create(server.wl_server);

    try Root.init(&server.root);
  }
};
