//! This is a simple way to define a keymap. To keep hashing consistent the
//! hash is generated here.
const Keymap = @This();

const std = @import("std");

const xkb = @import("xkbcommon");
const wlr = @import("wlroots");
const zlua = @import("zlua");

const Lua = &@import("main.zig").lua;

modifier: wlr.Keyboard.ModifierMask,
keycode: xkb.Keysym,
/// This is the location of the lua function in the lua registry
lua_ref_idx: i32,
options: struct {
  /// if false the callback is called on press
  on_release: bool,
},

pub fn callback(self: *const Keymap) void {
  const t = Lua.state.rawGetIndex(zlua.registry_index, self.lua_ref_idx);
  if (t != zlua.LuaType.function) {
    std.log.err("Failed to call keybind, it doesn't have a callback.", .{});
    Lua.state.pop(1);
    return;
  }

  Lua.state.call(.{ .args = 0, .results = 0 });
  Lua.state.pop(-1);
}

pub fn hash(modifier: wlr.Keyboard.ModifierMask, keycode: xkb.Keysym) u64 {
  const mod_val: u32 = @bitCast(modifier);
  const key_val: u32 = @intFromEnum(keycode);
  return (@as(u64, mod_val) << 32) | @as(u64, key_val);
}
