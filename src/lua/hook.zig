const Hook = @This();

const std = @import("std");

const THook = @import("../types/hook.zig");

const zlua = @import("zlua");

const gpa = std.heap.c_allocator;
const server = &@import("../main.zig").server;

pub fn add(L: *zlua.Lua) i32 {
  L.checkType(2, .table);

  var hook: *THook = gpa.create(THook) catch {
    L.raiseErrorStr("Lua error check your config", .{});
    return 0;
  };
  hook.events = std.ArrayList([]const u8).initCapacity(gpa, 1) catch {
    L.raiseErrorStr("Lua error check your config", .{});
    return 0;
  };

  // We support both a string and a table of strings as the first value of
  // add. Regardless of which type is passed in we create an arraylist of
  // []const u8's
  if (L.isTable(1)) {
    L.pushNil();
    while (L.next(1)) {
      if (L.isString(-1)) {
        const s = L.toString(-1) catch {
          L.raiseErrorStr("Lua error check your config", .{});
          return 0;
        };
        hook.events.append(gpa, s) catch {
          L.raiseErrorStr("Lua error check your config", .{});
          return 0;
        };
      }
      L.pop(1);
    }
  } else if (L.isString(1)) {
    const s = L.toString(1) catch {
      L.raiseErrorStr("Lua error check your config", .{});
      return 0;
    };
    hook.events.append(gpa, s) catch {
      L.raiseErrorStr("Lua error check your config", .{});
      return 0;
    };
  }

  _ = L.pushString("callback");
  _ = L.getTable(2);
  if (L.isFunction(-1)) {
    hook.options.lua_cb_ref_idx = L.ref(zlua.registry_index) catch {
      L.raiseErrorStr("Lua error check your config", .{});
      return 0;
    };
  }

  server.hooks.append(gpa, hook) catch {
    L.raiseErrorStr("Lua error check your config", .{});
    return 0;
  };

  for (hook.events.items) |value| {
    server.events.put(value, hook) catch {
      L.raiseErrorStr("Lua error check your config", .{});
      return 0;
    };
  }

  return 0;
}

pub fn del(L: *zlua.Lua) i32 {
  // TODO: impl
  _ = L;
  return 0;
}
