const Keyboard = @This();

const std = @import("std");
const gpa = std.heap.c_allocator;
const server = &@import("main.zig").server;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");
const xkb = @import("xkbcommon");

wlr_keyboard: *wlr.Keyboard,
device: *wlr.InputDevice,

keyboards: wl.list.Head(Keyboard, .link) = undefined,

link: wl.list.Link = undefined,

// Keyboard listeners
key: wl.Listener(*wlr.Keyboard.event.Key) = .init(handleKey),
key_map: wl.Listener(*wlr.Keyboard) = .init(handleKeyMap),
modifiers: wl.Listener(*wlr.Keyboard) = .init(handleModifiers),

// Device listeners
destroy: wl.Listener(*wlr.InputDevice) = .init(handleDestroy),


pub fn init(self: *Keyboard, device: *wlr.InputDevice) !void {
  self.* = .{
    .wlr_keyboard = device.toKeyboard(),
    .device = device,
  };

  const context = xkb.Context.new(.no_flags) orelse return error.ContextFailed;
  defer context.unref();

  const keymap = xkb.Keymap.newFromNames(context, null, .no_flags) orelse return error.KeymapFailed;
  defer keymap.unref();

  // TODO: configure this via lua later
  if (!self.wlr_keyboard.setKeymap(keymap)) return error.SetKeymapFailed;
  self.wlr_keyboard.setRepeatInfo(25, 600);

  self.wlr_keyboard.events.modifiers.add(&self.modifiers);
  self.wlr_keyboard.events.key.add(&self.key);
  self.wlr_keyboard.events.keymap.add(&self.key_map);

  device.events.destroy.add(&self.destroy);

  std.log.debug("adding keyboard: {s}", .{self.wlr_keyboard.base.name orelse "(null)"});

  server.seat.wlr_seat.setKeyboard(self.wlr_keyboard);

  self.keyboards.init();
  self.keyboards.append(self);
}

// pub fn destroy(self: *Keyboard) {
//
// }

fn handleModifiers(_: *wl.Listener(*wlr.Keyboard), wlr_keyboard: *wlr.Keyboard) void {
  server.seat.wlr_seat.setKeyboard(wlr_keyboard);
  server.seat.wlr_seat.keyboardNotifyModifiers(&wlr_keyboard.modifiers);
}

fn handleKey(_: *wl.Listener(*wlr.Keyboard.event.Key), event: *wlr.Keyboard.event.Key) void {
  // Translate libinput keycode -> xkbcommon
  // const keycode = event.keycode + 8;

  // TODO: lua handle keybinds here
  const handled = false;
  if (server.keyboard.wlr_keyboard.getModifiers().alt and event.state == .pressed) {
    // for (wlr_keyboard.xkb_state.?.keyGetSyms(keycode)) |sym| {
    //   if (keyboard.server.handleKeybind(sym)) {
    //     handled = true;
    //     break;
    //   }
    // }
  }

  if (!handled) {
    server.seat.wlr_seat.setKeyboard(server.keyboard.wlr_keyboard);
    server.seat.wlr_seat.keyboardNotifyKey(event.time_msec, event.keycode, event.state);
  }
}

fn handleKeyMap(_: *wl.Listener(*wlr.Keyboard), _: *wlr.Keyboard) void {
  std.log.err("Unimplemented handle keyboard keymap", .{});
}

pub fn handleDestroy(listener: *wl.Listener(*wlr.InputDevice), _: *wlr.InputDevice) void {
  const keyboard: *Keyboard = @fieldParentPtr("destroy", listener);

  std.log.debug("removing keyboard: {s}", .{keyboard.*.device.*.name orelse "(null)"});

  keyboard.link.remove();

  keyboard.modifiers.link.remove();
  keyboard.key.link.remove();
  keyboard.destroy.link.remove();

  gpa.destroy(keyboard);
}
