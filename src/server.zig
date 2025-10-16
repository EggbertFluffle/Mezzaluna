const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

pub const Server = struct {
	allocator: *wlr.Allocator,

	server: *wl.Server,
	event_loop: *wl.EventLoop,

	session: *wlr.Session,
	backend: *wlr.Backend,
	renderer: *wlr.Renderer,

	compositor: *wlr.Compositor,

	pub fn init() !Server {
		const server = try wl.Server.create();
		const event_loop = server.getEventLoop();

		var session: ?*wlr.Session = undefined;
		const backend = try wlr.Backend.autocreate(event_loop, &session);
		const renderer = try wlr.Renderer.autocreate(backend);

		// Do we need to fail if session is NULL

		return .{
			.server = server,
			.event_loop = event_loop,

			.session = session,
			.backend = backend,
			.renderer = renderer,

			.allocator = try wlr.Allocator.autocreate(backend, renderer),

			.compositor = try wlr.Compositor.create(server, 6, renderer),
		};
	}
};
