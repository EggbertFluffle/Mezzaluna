const Api = @This();

const std = @import("std");
const Keymap = @import("../keymap.zig");

const zlua = @import("zlua");
const xkb = @import("xkbcommon");
const wlr = @import("wlroots");

const gpa = std.heap.c_allocator;
const server = &@import("../main.zig").server;
const env_map = &@import("../main.zig").env_map;

pub fn add_keymap(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if (nargs < 3) {
    L.raiseErrorStr("Expected at least three arguments", .{});
    return 0;
  }

  // ensure the first three agrs of the correct types
  L.checkType(1, .string);
  L.checkType(2, .string);
  L.checkType(3, .table);

  var keymap: Keymap = undefined;
  keymap.options = .{
    .on_release = false,
  };

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

  _ = L.pushString("press");
  _ = L.getTable(3);
  if (L.isFunction(-1)) {
    keymap.lua_press_ref_idx = L.ref(zlua.registry_index) catch {
      L.raiseErrorStr("Lua error check your config", .{});
      return 0;
    };
  }

  _ = L.pushString("release");
  _ = L.getTable(3);
  if (L.isFunction(-1)) {
    keymap.lua_release_ref_idx = L.ref(zlua.registry_index) catch {
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

pub fn get_keybind(L: *zlua.Lua) i32 {
  _ = L;
  return 0;
}

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
