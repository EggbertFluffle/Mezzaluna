const std = @import("std");
const wlr = @import("wlroots");

const Server = @import("server.zig");

const gpa = std.heap.c_allocator;

pub fn main() !void {
  wlr.log.init(.debug, null);
  std.debug.print("Starting mezzaluna", .{});

  var server: Server = undefined;
  try server.init();

  var buf: [11]u8 = undefined;
  const socket = try server.wl_server.addSocketAuto(&buf);

  if (std.os.argv.len >= 2) {
    const cmd = std.mem.span(std.os.argv[1]);
    var child = std.process.Child.init(&[_][]const u8{ "/bin/sh", "-c", cmd }, gpa);
    var env_map = try std.process.getEnvMap(gpa);
    defer env_map.deinit();
    try env_map.put("WAYLAND_DISPLAY", socket);
    child.env_map = &env_map;
    try child.spawn();
  }

  server.backend.start() catch |err| {
    std.debug.panic("Failed to start backend: {}", .{err});
    return;
  };

  server.wl_server.run();
}
