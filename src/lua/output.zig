const std = @import("std");
const zlua = @import("zlua");
const wlr = @import("wlroots");

const Output = @import("../output.zig");

const gpa = std.heap.c_allocator;
const server = &@import("../main.zig").server;

pub fn get_all_ids(L: *zlua.Lua) i32 {
  var it = server.root.scene.outputs.iterator(.forward);
  var index: usize = 1;

  L.newTable();

  while(it.next()) |scene_output| : (index += 1) {
    if(scene_output.output.data == null) continue;

    const output = @as(*Output, @ptrCast(@alignCast(scene_output.output.data.?)));

    L.pushInteger(@intCast(index));
    L.pushInteger(@intCast(output.id));
    L.setTable(-3);
  }

  return 1;
}

pub fn get_focused_id(L: *zlua.Lua) i32 {
  if(server.seat.focused_output) |output| {
    L.pushInteger(@intCast(output.id));
    return 1;
  }

  return 0;
}

pub fn get_rate(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if(nargs != 1) {
    L.raiseErrorStr("Expected 1 argument, found", .{nargs});
  }

  L.checkType(1, .number);

  const output_id: u64 = @as(u64, @intCast(L.toInteger(1) catch {
    L.raiseErrorStr("Arg is not convertable to an int", .{});
  }));

  if(server.root.outputById(output_id)) |output| {
    L.pushInteger(@intCast(output.wlr_output.refresh));
    return 1;
  }

  return 0;
}

pub fn get_resolution(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if(nargs != 1) {
    L.raiseErrorStr("Expected 1 argument, found", .{nargs});
  }

  L.checkType(1, .number);

  const output_id: u64 = @as(u64, @intCast(L.toInteger(1) catch {
    L.raiseErrorStr("Arg is not convertable to an int", .{});
  }));

  if(server.root.outputById(output_id)) |output| {
    L.newTable();

    _ = L.pushString("width");
    L.pushInteger(@intCast(output.wlr_output.width));
    L.setTable(-3);

    _ = L.pushString("height");
    L.pushInteger(@intCast(output.wlr_output.height));
    L.setTable(-3);

    return 1;
  }

  return 0;
}

// Return the serial of the output
pub fn get_serial(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if(nargs != 1) {
    L.raiseErrorStr("Expected 1 argument, found", .{nargs});
  }

  L.checkType(1, .number);

  errdefer L.raiseErrorStr("Arg is not convertable to an int", .{});
  const output_id: u64 = @intCast(try L.toInteger(1));

  if(server.root.outputById(output_id)) |output| {
    if(output.wlr_output.serial == null) return 0;

    _ = L.pushString(std.mem.span(output.wlr_output.serial.?));
    return 1;
  }

  return 0;
}

// Return the make of the output
pub fn get_make(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if(nargs != 1) {
    L.raiseErrorStr("Expected 1 argument, found", .{nargs});
  }

  L.checkType(1, .number);

  errdefer L.raiseErrorStr("Arg is not convertable to an int", .{});
  const output_id: u64 = @intCast(try L.toInteger(1));

  if(server.root.outputById(output_id)) |output| {
    if(output.wlr_output.make == null) return 0;

    _ = L.pushString(std.mem.span(output.wlr_output.make.?));
    return 1;
  }

  return 0;
}

// Return the model of the output
pub fn get_model(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if(nargs != 1) {
    L.raiseErrorStr("Expected 1 argument, found", .{nargs});
  }

  L.checkType(1, .number);

  errdefer L.raiseErrorStr("Arg is not convertable to an int", .{});
  const output_id: u64 = @intCast(try L.toInteger(1));

  if(server.root.outputById(output_id)) |output| {
    if(output.wlr_output.model == null) return 0;

    _ = L.pushString(std.mem.span(output.wlr_output.model.?));
    return 1;
  }

  return 0;
}

// Return the description of the output
pub fn get_description(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if(nargs != 1) {
    L.raiseErrorStr("Expected 1 argument, found", .{nargs});
  }

  L.checkType(1, .number);

  errdefer L.raiseErrorStr("Arg is not convertable to an int", .{});
  const output_id: u64 = @intCast(try L.toInteger(1));

  if(server.root.outputById(output_id)) |output| {
    if(output.wlr_output.description == null) return 0;

    _ = L.pushString(std.mem.span(output.wlr_output.description.?));
    return 1;
  }

  return 0;
}

// Return the name of the output
pub fn get_name(L: *zlua.Lua) i32 {
  const nargs: i32 = L.getTop();

  if(nargs != 1) {
    L.raiseErrorStr("Expected 1 argument, found", .{nargs});
  }

  L.checkType(1, .number);

  errdefer L.raiseErrorStr("Arg is not convertable to an int", .{});
  const output_id: u64 = @intCast(try L.toInteger(1));

  if(server.root.outputById(output_id)) |output| {
    _ = L.pushString(std.mem.span(output.wlr_output.name));
    return 1;
  }

  return 0;
}
