//! This is a simple way to define a hook.
const Hook = @This();

const std = @import("std");

const xkb = @import("xkbcommon");
const wlr = @import("wlroots");
const zlua = @import("zlua");

const Event = @import("events.zig");
const Lua = &@import("../main.zig").lua;

events: std.ArrayList([]const u8), // a list of events
options: struct {
  // group: []const u8, // TODO: do we need groups?
  /// This is the location of the callback lua function in the lua registry
  lua_cb_ref_idx: i32,
},

pub fn callback(self: *const Hook, args: anytype) void {
  const ArgsType = @TypeOf(args);
  const args_type_info = @typeInfo(ArgsType);
  if (args_type_info != .@"struct") {
    @compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType));
  }

  const t = Lua.state.rawGetIndex(zlua.registry_index, self.options.lua_cb_ref_idx);
  if (t != zlua.LuaType.function) {
    std.log.err("Failed to call hook, it doesn't have a callback.", .{});
    Lua.state.pop(1);
    return;
  }

  var i: u8 = 0;
  inline for (args, 0..) |field, k| {
    // std.log.debug("{any}", .{field});

    // oh dear god I hope this works
    std.log.debug("sldkjf {any}", .{field});
    try Lua.state.pushAny(field);
    i = k;
  }

  // TODO: we need to send some data along with the callback, this data will
  // change based on the event which the user is hooking into
  Lua.state.protectedCall(.{ .args = i, .results = 0 }) catch {
  };
  Lua.state.pop(-1);
}
