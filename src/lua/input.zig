const Api = @This();

const std = @import("std");
const zlua = @import("zlua");
const xkb = @import("xkbcommon");
const wlr = @import("wlroots");

const Keymap = @import("../types/keymap.zig");
const Utils = @import("../utils.zig");

const server = &@import("../main.zig").server;

fn parse_modkeys(modStr: []const u8) wlr.Keyboard.ModifierMask {
  var it = std.mem.splitScalar(u8, modStr, '|');
  var modifiers = wlr.Keyboard.ModifierMask{};
  while (it.next()) |m| {
    inline for (std.meta.fields(@TypeOf(modifiers))) |f| {
      if (f.type == bool and std.mem.eql(u8, m, f.name)) {
        @field(modifiers, f.name) = true;
      }
    }
  }

  return modifiers;
}

pub fn add_keymap(L: *zlua.Lua) i32 {
  var keymap: Keymap = undefined;
  keymap.options.repeat = true;

  const mod = L.checkString(1);
  keymap.modifier = parse_modkeys(mod);

  const key = L.checkString(2);
  keymap.keycode = xkb.Keysym.fromName(key, .no_flags);

  _ = L.pushString("press");
  _ = L.getTable(3);
  if (L.isFunction(-1)) {
    keymap.options.lua_press_ref_idx = L.ref(zlua.registry_index) catch {
      L.raiseErrorStr("Lua error check your config", .{}); // TODO: Insert more descrptive errors
    };
  }

  _ = L.pushString("release");
  _ = L.getTable(3);
  if (L.isFunction(-1)) {
    keymap.options.lua_release_ref_idx = L.ref(zlua.registry_index) catch {
      L.raiseErrorStr("Lua error check your config", .{}); // TODO: Insert more descrptive errors
    };
  }

  _ = L.pushString("repeat");
  _ = L.getTable(3);
  keymap.options.repeat = L.isNil(-1) or L.toBoolean(-1);

  const hash = Keymap.hash(keymap.modifier, keymap.keycode);
  server.keymaps.put(hash, keymap) catch Utils.oomPanic();

  L.pushNil();
  return 1;
}

pub fn del_keymap(L: *zlua.Lua) i32 {
  L.checkType(1, .string);
  L.checkType(2, .string);

  var keymap: Keymap = undefined;
  const mod = L.checkString(1);

  keymap.modifier = parse_modkeys(mod);

  const key = L.checkString(2);

  keymap.keycode = xkb.Keysym.fromName(key, .no_flags);
  _ = server.keymaps.remove(Keymap.hash(keymap.modifier, keymap.keycode));

  L.pushNil();
  return 1;
}
