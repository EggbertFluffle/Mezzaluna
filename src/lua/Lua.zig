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

pub fn loadRuntimeDir(self: *zlua.Lua) !void {
  const path_dir = try std.fs.path.joinZ(gpa, &[_][]const u8{
    config.runtime_path_prefix,
    "share",
    "mezzaluna",
  });
  defer gpa.free(path_dir);

  {
    _ = try self.getGlobal("mez");
    _ = self.getField(-1, "path");
    defer self.pop(2);
    _ = self.pushString(path_dir);
    self.setField(-2, "runtime");
  }

  const path_full = try std.fs.path.joinZ(gpa, &[_][]const u8{
    path_dir,
    "init.lua",
  });
  defer gpa.free(path_full);

  self.doFile(path_full) catch {
    const err = try self.toString(-1);
    std.log.debug("Failed to run lua file: {s}", .{err});
  };
}

fn loadBaseConfig(self: *zlua.Lua) !void {
  const lua_path = "mez.path.base_config";
  if (!Bridge.getNestedField(self, @constCast(lua_path[0..]))) {
    std.log.err("Base config path not found. is your runtime dir setup?", .{});
    return;
  }
  const path = self.toString(-1) catch |err| {
    std.log.err("Failed to pop the base config path from the lua stack. {}", .{err});
    return;
  };
  self.pop(-1);
  try self.doFile(path);
}

fn loadConfigDir(self: *zlua.Lua) !void {
  const lua_path = "mez.path.config";
  if (!Bridge.getNestedField(self, @constCast(lua_path[0..]))) {
    std.log.err("Config path not found. is your runtime dir setup?", .{});
    return;
  }
  const path = self.toString(-1) catch |err| {
    std.log.err("Failed to pop the config path from the lua stack. {}", .{err});
    return;
  };
  self.pop(-1);
  try self.doFile(path);
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

  loadRuntimeDir(self.state) catch |err| if (err == error.LuaRuntime) {
    std.log.warn("{s}", .{try self.state.toString(-1)});
  };

  loadBaseConfig(self.state) catch |err| if (err == error.LuaRuntime) {
    std.log.warn("{s}", .{try self.state.toString(-1)});
  };

  loadConfigDir(self.state) catch |err| if (err == error.LuaRuntime) {
    std.log.warn("{s}", .{try self.state.toString(-1)});
  };

  std.log.debug("Loaded lua", .{});
}

pub fn deinit(self: *Lua) void {
  self.state.deinit();
}
