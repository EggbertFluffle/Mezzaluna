const std = @import("std");
const zlua = @import("zlua");

const gpa = std.heap.c_allocator;

const env_map = &@import("../main.zig").env_map;

pub fn spawn(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if (nargs < 1) {
    L.raiseErrorStr("Expected at least one arguments", .{});
    return 0;
  }

  L.checkType(1, .string);

  const cmd = L.toString(1) catch {
    L.raiseErrorStr("Lua error check your config", .{});
    return 0;
  };

  var child = std.process.Child.init(&[_][]const u8{ "/bin/sh", "-c", cmd }, gpa);
  child.env_map = env_map;
  child.spawn() catch {
    std.log.err("Unable to spawn process \"{s}\"", .{cmd});
  };

  return 0;
}
