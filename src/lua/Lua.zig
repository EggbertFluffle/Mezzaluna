const Lua = @This();

const std = @import("std");
const config = @import("config");
const zlua = @import("zlua");

const Bridge = @import("Bridge.zig");
const Fs =     @import("Fs.zig");
const Input =  @import("Input.zig");
const Api =    @import("Api.zig");
const Hook =   @import("Hook.zig");
const View =   @import("View.zig");
const Output = @import("Output.zig");

const gpa = std.heap.c_allocator;

state: *zlua.Lua,

fn loadRuntimeDir(self: *Lua) !void {
  const tmppath = try std.fs.path.join(gpa, &[_][]const u8{
    config.runtime_path_prefix,
    "share",
    "mezzaluna",
    "init.lua",
  });
  const path = try gpa.dupeZ(u8, tmppath);

  self.state.doFile(path) catch {
    const err = try self.state.toString(-1);
    std.log.debug("Failed to run lua file: {s}", .{err});
  };
}

fn loadConfigDir(self: *Lua) !void {
  const lua_path = "mez.path.config";
  if (!Bridge.getNestedField(self, @constCast(lua_path[0..]))) {
    std.log.err("Config path not found. is your runtime dir setup?", .{});
    return;
  }
  const path = self.state.toString(-1) catch |err| {
    std.log.err("Failed to pop the config path from the lua stack. {}", .{err});
    return;
  };
  self.state.pop(-1);
  try self.state.doFile(path);
}

pub fn openLibs(self: *zlua.Lua) void {
  {
    self.newTable();
    defer _ = self.setGlobal("mez");
    {
      self.newTable();
      defer _ = self.setField(-2, "path");
    }
    {
      const fs_funcs = zlua.fnRegsFromType(Fs);
      self.newLib(fs_funcs);
      self.setField(-2, "fs");
    }
    {
      const input_funcs = zlua.fnRegsFromType(Input);
      self.newLib(input_funcs);
      self.setField(-2, "input");
    }
    {
      const hook_funcs = zlua.fnRegsFromType(Hook);
      self.newLib(hook_funcs);
      self.setField(-2, "hook");
    }
    {
      const api_funcs = zlua.fnRegsFromType(Api);
      self.newLib(api_funcs);
      self.setField(-2, "api");
    }
    {
      const view_funcs = zlua.fnRegsFromType(View);
      self.newLib(view_funcs);
      self.setField(-2, "view");
    }
    {
      const output_funcs = zlua.fnRegsFromType(Output);
      self.newLib(output_funcs);
      self.setField(-2, "output");
    }
  }
}

pub fn init(self: *Lua) !void {
  self.state = try zlua.Lua.init(gpa);
  errdefer self.state.deinit();
  self.state.openLibs();

  openLibs(self.state);

  loadRuntimeDir(self) catch |err| {
    if (err == error.LuaRuntime) {
      std.log.warn("{s}", .{try self.state.toString(-1)});
    }
  };

  loadConfigDir(self) catch |err| {
    if (err == error.LuaRuntime) {
      std.log.warn("{s}", .{try self.state.toString(-1)});
    }
  };

  std.log.debug("Loaded lua", .{});
}

pub fn deinit(self: *Lua) void {
  self.state.deinit();
}
