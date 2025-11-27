const std = @import("std");
const zlua = @import("zlua");
const wlr = @import("wlroots");

const gpa = std.heap.c_allocator;

const env_map = &@import("../main.zig").env_map;
const server = &@import("../main.zig").server;

/// ---Spawn new application via the shell command
/// ---@param cmd string Command to be run by a shell
pub fn spawn(L: *zlua.Lua) i32 {
  const cmd = L.checkString(1);

  var child = std.process.Child.init(&[_][]const u8{ "/bin/sh", "-c", cmd }, gpa);
  child.env_map = env_map;
  child.spawn() catch {
    L.raiseErrorStr("Unable to spawn process", .{}); // TODO: Give more descriptive error
  };

  L.pushNil();
  return 1;
}

/// ---Exit mezzaluna
pub fn exit(L: *zlua.Lua) i32 {
  server.wl_server.terminate();

  L.pushNil();
  return 1;
}

/// ---Change to a different virtual terminal
/// ---@param vt_num integer virtual terminal number to switch to
pub fn change_vt(L: *zlua.Lua) i32 {
  const vt_num: c_uint = @intCast(L.checkInteger(1));

  if (server.session) |session| {
    std.log.debug("Changing virtual terminal to {d}", .{vt_num});
    wlr.Session.changeVt(session, vt_num) catch {
      L.raiseErrorStr("Failed to switch vt", .{});
    };
  } else {
    L.raiseErrorStr("Mez has not been initialized yet", .{});
  }

  L.pushNil();
  return 1;
}
