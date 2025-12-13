const LuaUtils = @This();

const std = @import("std");
const zlua = @import("zlua");

pub fn coerceNumber(comptime x: type, number: zlua.Number) error{InvalidNumber}!x {
  if (number < std.math.minInt(x) or number > std.math.maxInt(x) or std.math.isNan(number)) {
    return error.InvalidNumber;
  }
  switch (@typeInfo(x)) {
    .int => return @as(x, @intFromFloat(number)),
    .float => return @floatCast(number),
    else => @compileError("unsupported type"),
  }
}

pub fn coerceInteger(comptime x: type, number: zlua.Integer) error{InvalidInteger}!x {
  if (number < std.math.minInt(x) or number > std.math.maxInt(x) or std.math.isNan(number)) {
    return error.InvalidInteger;
  }
  switch (@typeInfo(x)) {
    .int => return @intCast(number),
    .float => return @as(x, @floatFromInt(number)),
    else => @compileError("unsupported type"),
  }
}
