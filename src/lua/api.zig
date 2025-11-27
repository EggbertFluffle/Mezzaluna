const std = @import("std");
const zlua = @import("zlua");
const wlr = @import("wlroots");

const gpa = std.heap.c_allocator;

const env_map = &@import("../main.zig").env_map;
const server = &@import("../main.zig").server;

pub fn spawn(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if (nargs < 1) {
    L.raiseErrorStr("Expected at least one arguments", .{});
    return 0;
  }

  L.checkType(1, .string);

  const cmd = L.toString(1) catch {
    L.raiseErrorStr("Lua error check your config", .{});
  };

  var child = std.process.Child.init(&[_][]const u8{ "/bin/sh", "-c", cmd }, gpa);
  child.env_map = env_map;
  child.spawn() catch {
    std.log.err("Unable to spawn process \"{s}\"", .{cmd});
  };

  return 0;
}

pub fn exit(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if (nargs != 0) {
    L.raiseErrorStr("Expected no arguments", .{});
  }

  server.wl_server.terminate();

  return 0;
}

pub fn change_vt(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if (nargs != 1) {
    L.raiseErrorStr("Expected 1 argument, found {d}", .{nargs});
  }

  L.checkType(1, .number);

  const vt_num: c_uint = @intCast(L.toInteger(1) catch {
      L.raiseErrorStr("Failed to switch vt", .{});
  });

  if (server.session) |session| {
    std.log.debug("Changing virtual terminal to {d}", .{vt_num});
    wlr.Session.changeVt(session, vt_num) catch {
      L.raiseErrorStr("Failed to switch vt", .{});
    };
  } else {
    L.raiseErrorStr("Mez has not been initialized yet", .{});
  }

  return 0;
}
