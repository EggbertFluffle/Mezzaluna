const Hook = @This();

const std = @import("std");
const zlua = @import("zlua");

const THook = @import("../types/Hook.zig");
const Utils = @import("../Utils.zig");

const gpa = std.heap.c_allocator;
const server = &@import("../main.zig").server;

pub fn add(L: *zlua.Lua) i32 {
  L.checkType(2, .table);

  errdefer Utils.oomPanic();
  var hook: *THook = try gpa.create(THook);
  hook.events = try std.ArrayList([]const u8).initCapacity(gpa, 1);

  // We support both a string and a table of strings as the first value of
  // add. Regardless of which type is passed in we create an arraylist of
  // []const u8's
  if (L.isTable(1)) {
    L.pushNil();
    while (L.next(1)) {
      if (L.isString(-1)) {
        const s = L.checkString(-1);
        try hook.events.append(gpa, s);
      }
      L.pop(1);
    }
  } else if (L.isString(1)) {
    const s = L.checkString(1);
    try hook.events.append(gpa, s);
  }

  _ = L.pushString("callback");
  _ = L.getTable(2);
  if (L.isFunction(-1)) {
    hook.options.lua_cb_ref_idx = L.ref(zlua.registry_index) catch {
      L.raiseErrorStr("Lua error check your config", .{}); // TODO: Give more descriptive error
    };
  }

  try server.hooks.append(gpa, hook);

  for (hook.events.items) |value| {
    try server.events.put(value, hook);
  }

  return 0;
}

pub fn del(L: *zlua.Lua) i32 {
  // TODO: impl
  _ = L;
  return 0;
}
