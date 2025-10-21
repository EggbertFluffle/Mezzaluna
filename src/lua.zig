const Lua = @This();

const std = @import("std");
const config = @import("config");
const zlua = @import("zlua");

const gpa = std.heap.c_allocator;

state: *zlua.Lua,

fn loadRuntimeDir(self: *Lua) !void {
  const tmppath = try std.fs.path.join(gpa, &[_][]const u8{
    config.runtime_path_prefix,
    "share",
    "mezzaluna",
    "init.lua",
  });
  var path_buffer = try gpa.alloc(u8, tmppath.len + 1);
  std.mem.copyForwards(u8, path_buffer[0..tmppath.len], tmppath);
  path_buffer[tmppath.len] = 0;
  const path: [:0]u8 = path_buffer[0..tmppath.len :0];

  try self.state.doFile(path);
}

pub fn init(self: *Lua) !void {
  self.state = try zlua.Lua.init(gpa);
  errdefer self.state.deinit();
  self.state.openLibs();

  {
    self.state.newTable();
    defer _ = self.state.pushString("mez");
  }

  try loadRuntimeDir(self);

  std.log.debug("Loaded lua", .{});
}

pub fn deinit(self: *Lua) void {
  self.state.deinit();
}
