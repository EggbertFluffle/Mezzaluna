const std = @import("std");

const Server = @import("server.zig").Server;

pub fn main() !void {
  std.debug.print("Starting mezzaluna", .{});
  _ = try Server.init();
}
