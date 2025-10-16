const std = @import("std");

const Server = @import("server.zig").Server;

pub fn main() !void {
  _ = try Server.init();
}
