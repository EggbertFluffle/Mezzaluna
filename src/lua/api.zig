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
    return 0;
  };

  var child = std.process.Child.init(&[_][]const u8{ "/bin/sh", "-c", cmd }, gpa);
  child.env_map = env_map;
  child.spawn() catch {
    std.log.err("Unable to spawn process \"{s}\"", .{cmd});
  };

  return 0;
}

pub fn close(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if (nargs != 0) {
    L.raiseErrorStr("Expected no arguments", .{});
    return 0;
  }

  if(server.seat.focused_view) |view| {
    view.xdg_toplevel.sendClose();
  }

  return 0;
}

pub fn exit(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if (nargs != 0) {
    L.raiseErrorStr("Expected no arguments", .{});
    return 0;
  }

  server.wl_server.terminate();

  return 0;
}

pub fn chvt(L: *zlua.Lua) i32 {
  L.checkType(1, .number);
  const f = L.toNumber(-1) catch unreachable;
  const n: u32 = @intFromFloat(f);

  if (server.session) |session| {
    wlr.Session.changeVt(session, n) catch {
      L.raiseErrorStr("Failed to switch vt", .{});
    };
  } else {
    L.raiseErrorStr("Mez has not been initialized yet", .{});
  }

  return 0;
}
