const Api = @This();

const std = @import("std");
const server = &@import("../main.zig").server;
const Keymap = @import("../keymap.zig");

const zlua = @import("zlua");
const xkb = @import("xkbcommon");
const wlr = @import("wlroots");

const gpa = std.heap.c_allocator;

pub fn add_keymap(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();
  if (nargs < 3) {
    L.raiseErrorStr("Expected at least three arguments", .{});
    return 0;
  }

  // ensure the first three agrs of the correct types
  L.checkType(1, .string);
  L.checkType(2, .string);
  L.checkType(3, .function);

  var keymap: Keymap = undefined;

  const mod = L.toString(1) catch {
    L.raiseErrorStr("Lua error check your config", .{});
    return 0;
  };
  var it = std.mem.splitScalar(u8, mod, '|');
  var modifiers = wlr.Keyboard.ModifierMask{};
  while (it.next()) |m| {
    // TODO: can we generate this at comptime?
    if (std.mem.eql(u8, m, "shift")) {
      modifiers.shift = true;
    } else if (std.mem.eql(u8, m, "caps")) {
      modifiers.caps = true;
    } else if (std.mem.eql(u8, m, "ctrl")) {
      modifiers.ctrl = true;
    } else if (std.mem.eql(u8, m, "alt")) {
      modifiers.alt = true;
    } else if (std.mem.eql(u8, m, "mod2")) {
      modifiers.mod2 = true;
    } else if (std.mem.eql(u8, m, "mod3")) {
      modifiers.mod3 = true;
    } else if (std.mem.eql(u8, m, "logo")) {
      modifiers.logo = true;
    } else if (std.mem.eql(u8, m, "mod5")) {
      modifiers.mod5 = true;
    }
  }
  keymap.modifier = modifiers;

  const key = L.toString(2) catch {
    L.raiseErrorStr("Lua error check your config", .{});
    return 0;
  };
  keymap.keycode = xkb.Keysym.fromName(key, .no_flags);

  L.checkType(3, .function);
  keymap.lua_ref_idx = L.ref(zlua.registry_index) catch {
    L.raiseErrorStr("Lua error check your config", .{});
    return 0;
  };

  // FIXME: for som reason I can't seem to get this to validate that the 4th
  // argument exists unless there's a 5th argument. It doesn't seem to matter
  // what type the 5th is just that it's there.
  if (nargs == 4) {
    // L.checkType(4, .table);
    // _ = L.pushString("on_release");
    // _ = L.getTable(4);
    // const b = L.toBoolean(-1);
    // L.pop(-1);
    // L.pop(-1);
  }

  const hash = Keymap.hash(keymap.modifier, keymap.keycode);
  server.keymaps.put(hash, keymap) catch |err| {
    std.log.err("Failed to add keymap to keymaps: {}", .{err});
    return 0;
  };

  return 0;
}

pub fn get_keybind(L: *zlua.Lua) i32 {
  _ = L;
  return 0;
}
