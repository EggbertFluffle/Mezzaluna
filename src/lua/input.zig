const Api = @This();

const std = @import("std");
const Keymap = @import("../types/keymap.zig");

const zlua = @import("zlua");
const xkb = @import("xkbcommon");
const wlr = @import("wlroots");

const gpa = std.heap.c_allocator;
const server = &@import("../main.zig").server;

fn parse_modkeys(modStr: []const u8) wlr.Keyboard.ModifierMask {
  var it = std.mem.splitScalar(u8, modStr, '|');
  var modifiers = wlr.Keyboard.ModifierMask{};
  while (it.next()) |m| {
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

  return modifiers;
}

pub fn add_keymap(L: *zlua.Lua) i32 {
  // ensure the first three agrs of the correct types
  L.checkType(1, .string);
  L.checkType(2, .string);
  L.checkType(3, .table);

  var keymap: Keymap = undefined;
  keymap.options.repeat = true;

  const mod = L.toString(1) catch {
    L.raiseErrorStr("Lua error check your config", .{});
    return 0;
  };
  keymap.modifier = parse_modkeys(mod);

  const key = L.toString(2) catch {
    L.raiseErrorStr("Lua error check your config", .{});
    return 0;
  };
  keymap.keycode = xkb.Keysym.fromName(key, .no_flags);

  _ = L.pushString("press");
  _ = L.getTable(3);
  if (L.isFunction(-1)) {
    keymap.options.lua_press_ref_idx = L.ref(zlua.registry_index) catch {
      L.raiseErrorStr("Lua error check your config", .{});
      return 0;
    };
  }

  _ = L.pushString("release");
  _ = L.getTable(3);
  if (L.isFunction(-1)) {
    keymap.options.lua_release_ref_idx = L.ref(zlua.registry_index) catch {
      L.raiseErrorStr("Lua error check your config", .{});
      return 0;
    };
  }

  _ = L.pushString("repeat");
  _ = L.getTable(3);
  keymap.options.repeat = L.isNil(-1) or L.toBoolean(-1);

  const hash = Keymap.hash(keymap.modifier, keymap.keycode);
  server.keymaps.put(hash, keymap) catch |err| {
    std.log.err("Failed to add keymap to keymaps: {}", .{err});
    return 0;
  };

  return 0;
}

pub fn del_keymap(L: *zlua.Lua) i32 {
  L.checkType(1, .string);
  L.checkType(2, .string);

  var keymap: Keymap = undefined;
  const mod = L.toString(1) catch {
    L.raiseErrorStr("Lua error check your config", .{});
    return 0;
  };
  keymap.modifier = parse_modkeys(mod);

  const key = L.toString(2) catch {
    L.raiseErrorStr("Lua error check your config", .{});
    return 0;
  };
  keymap.keycode = xkb.Keysym.fromName(key, .no_flags);
  _ = server.keymaps.remove(Keymap.hash(keymap.modifier, keymap.keycode));

  return 0;
}
