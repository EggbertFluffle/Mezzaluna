const Bridge = @This();

const std = @import("std");
const Lua = @import("lua.zig");

const gpa = std.heap.c_allocator;

pub fn getNestedField(L: *Lua, path: []u8) bool {
  var tokens = std.mem.tokenizeScalar(u8, path, '.');
  var first = true;

  while (tokens.next()) |token| {
    const tok = gpa.dupeZ(u8, token) catch return false;
    if (first) {
      _ = L.state.getGlobal(tok) catch return false;
      first = false;
    } else {
      _ = L.state.getField(-1, tok);
      L.state.remove(-2);
    }

    if (L.state.isNil(-1)) {
      return false;
    }
  }

  return true;
}
