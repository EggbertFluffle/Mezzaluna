const std = @import("std");
const zlua = @import("zlua");
const wlr = @import("wlroots");

const View = @import("../view.zig");

const gpa = std.heap.c_allocator;

const server = &@import("../main.zig").server;

pub fn get_all_ids(L: *zlua.Lua) i32 {
  var it = server.root.scene.tree.children.iterator(.forward);
  var index: usize = 1;

  L.newTable();

  while(it.next()) |node| : (index += 1) {
    if(node.data == null) continue;

    const view = @as(*View, @ptrCast(@alignCast(node.data.?)));

    L.pushInteger(@intCast(index));
    L.pushInteger(@intCast(view.id));
    L.setTable(-3);
  }

  return 1;
}

pub fn get_focused_id(L: *zlua.Lua) i32 {
  if(server.seat.focused_view) |view| {
    L.pushInteger(@intCast(view.id));
    return 1;
  }

  return 0;
}

pub fn set_position(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if (nargs != 3) {
    L.raiseErrorStr("Expected 3 arguments, found {d}", .{nargs});
    return 0;
  }

  for (1..@intCast(nargs + 1)) |i| {
    L.checkType(@intCast(i), .number);
  }

  const view_id: u64 = @as(u64, @intCast(L.toInteger(1) catch { L.raiseErrorStr("Arg is not convertable to an int", .{}); }));
  const x: i32 = @as(i32, @intFromFloat(L.toNumber(2) catch { L.raiseErrorStr("Arg is not convertable to an int", .{}); }));
  const y: i32 = @as(i32, @intFromFloat(L.toNumber(3) catch { L.raiseErrorStr("Arg is not convertable to an int", .{}); }));

  const view = server.root.viewById(view_id);
  if(view == null) {
    L.raiseErrorStr("View with id {d} does not exist", .{view_id});
    return 0;
  }

  view.?.setPosition(x, y);

  return 0;
}

pub fn set_size(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if (nargs != 3) {
    L.raiseErrorStr("Expected 3 arguments, found {d}", .{nargs});
    return 0;
  }

  for (1..@intCast(nargs + 1)) |i| {
    L.checkType(@intCast(i), .number);
  }

  const view_id: u64 = @as(u64, @intCast(L.toInteger(1) catch { L.raiseErrorStr("Arg is not convertable to an int", .{}); }));
  const width: i32 = @as(i32, @intFromFloat(L.toNumber(2) catch { L.raiseErrorStr("Arg is not convertable to an int", .{}); }));
  const height: i32 = @as(i32, @intFromFloat(L.toNumber(3) catch { L.raiseErrorStr("Arg is not convertable to an int", .{}); }));

  const view = server.root.viewById(view_id);
  if(view == null) {
    L.raiseErrorStr("View with id {d} does not exist", .{view_id});
    return 0;
  }

  view.?.setSize(width, height);

  return 0;
}

pub fn set_focused(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if(nargs != 1) {
    L.raiseErrorStr("Expected 1 arguments, found {d}", .{nargs});
    return 0;
  }

  L.checkType(1, .number);

  const view_id: u64 = @as(u64, @intCast(L.toInteger(1) catch { L.raiseErrorStr("Arg is not convertable to an int", .{}); }));

  const view = server.root.viewById(view_id);
  if(view == null) {
    L.raiseErrorStr("View with id {d} does not exist", .{view_id});
    return 0;
  }

  view.?.setFocused();

  return 0;
}

pub fn get_title(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if(nargs != 1) {
    L.raiseErrorStr("Expected 1 arguments, found {d}", .{nargs});
    return 0;
  }

  L.checkType(1, .number);

  const view_id: u64 = @as(u64, @intCast(L.toInteger(1) catch { L.raiseErrorStr("Arg is not convertable to an int", .{}); }));

  if(server.root.viewById(view_id)) |view| {
    if(view.xdg_toplevel.title == null) return 0;

    _ = L.pushString(std.mem.span(view.xdg_toplevel.title.?));
    return 1;
  }

  return 0;
}

pub fn get_app_id(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if(nargs != 1) {
    L.raiseErrorStr("Expected 1 arguments, found {d}", .{nargs});
    return 0;
  }

  L.checkType(1, .number);

  const view_id: u64 = @as(u64, @intCast(L.toInteger(1) catch { L.raiseErrorStr("Arg is not convertable to an int", .{}); }));

  if(server.root.viewById(view_id)) |view| {
    if(view.xdg_toplevel.app_id == null) return 0;

    _ = L.pushString(std.mem.span(view.xdg_toplevel.app_id.?));
    return 1;
  }

  return 0;
}
