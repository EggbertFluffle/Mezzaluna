const Fs = @This();

const std = @import("std");
const zlua = @import("zlua");

const Lua = @import("lua.zig");

const gpa = std.heap.c_allocator;

/// ---Join any number of paths into one path
/// ---@vararg string paths to join
/// ---@return string?
pub fn joinpath(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();
  if (nargs < 2) {
    L.raiseErrorStr("Expected at least two paths to join", .{});
    return 0;
  }

  var paths = std.ArrayList([:0]const u8).initCapacity(gpa, @intCast(nargs)) catch {
    return 0;
  };
  defer paths.deinit(gpa);

  var i: u8 = 1;
  while (i <= nargs) : (i += 1) {
    if (!L.isString(i)) {
      L.raiseErrorStr("Expected string at argument %d", .{i});
      return 0;
    }

    const partial_path = L.toString(i) catch unreachable;
    paths.append(gpa, partial_path) catch {
      // TODO: tell lua?
      return 0;
    };
  }

  const final_path: []const u8 = std.fs.path.join(gpa, paths.items) catch {
    // TODO: tell lua?
    return 0;
  };
  _ = L.pushString(final_path);

  return 1;
}
