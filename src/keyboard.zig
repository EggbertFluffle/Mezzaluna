const Keyboard = @This();

const std = @import("std");
const gpa = std.heap.c_allocator;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");
const xkb = @import("xkbcommon");

const Server = @import("server.zig");

server: *Server,
link: wl.list.Link = undefined,
device: *wlr.InputDevice,

modifiers: wl.Listener(*wlr.Keyboard) = .init(handleModifiers),
key: wl.Listener(*wlr.Keyboard.event.Key) = .init(handleKey),
destroy: wl.Listener(*wlr.InputDevice) = .init(handleDestroy),

pub fn create(server: *Server, device: *wlr.InputDevice) !void {
  const keyboard = try gpa.create(Keyboard);
  errdefer gpa.destroy(keyboard);

  keyboard.* = .{
    .server = server,
    .device = device,
  };

  const context = xkb.Context.new(.no_flags) orelse return error.ContextFailed;
  defer context.unref();
  const keymap = xkb.Keymap.newFromNames(context, null, .no_flags) orelse return error.KeymapFailed;
  defer keymap.unref();

  const wlr_keyboard = device.toKeyboard();
  // TODO: configure this via lua later
  if (!wlr_keyboard.setKeymap(keymap)) return error.SetKeymapFailed;
  wlr_keyboard.setRepeatInfo(25, 600);

  wlr_keyboard.events.modifiers.add(&keyboard.modifiers);
  wlr_keyboard.events.key.add(&keyboard.key);
  device.events.destroy.add(&keyboard.destroy);

  std.log.debug("adding keyboard: {s}", .{keyboard.*.device.*.name orelse "(null)"});

  server.seat.setKeyboard(wlr_keyboard);
  server.keyboards.append(keyboard);
}

pub fn handleModifiers(listener: *wl.Listener(*wlr.Keyboard), wlr_keyboard: *wlr.Keyboard) void {
  const keyboard: *Keyboard = @fieldParentPtr("modifiers", listener);
  keyboard.server.seat.setKeyboard(wlr_keyboard);
  keyboard.server.seat.keyboardNotifyModifiers(&wlr_keyboard.modifiers);
}

pub fn handleKey(listener: *wl.Listener(*wlr.Keyboard.event.Key), event: *wlr.Keyboard.event.Key) void {
  const keyboard: *Keyboard = @fieldParentPtr("key", listener);
  const wlr_keyboard = keyboard.device.toKeyboard();

  // Translate libinput keycode -> xkbcommon
  // const keycode = event.keycode + 8;

  // TODO: lua handle keybinds here
  const handled = false;
  if (wlr_keyboard.getModifiers().alt and event.state == .pressed) {
    // for (wlr_keyboard.xkb_state.?.keyGetSyms(keycode)) |sym| {
    //   if (keyboard.server.handleKeybind(sym)) {
    //     handled = true;
    //     break;
    //   }
    // }
  }

  if (!handled) {
    keyboard.server.seat.setKeyboard(wlr_keyboard);
    keyboard.server.seat.keyboardNotifyKey(event.time_msec, event.keycode, event.state);
  }
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
