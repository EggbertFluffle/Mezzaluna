const RemoteLua = @This();

const std = @import("std");
const wayland = @import("wayland");
const Utils = @import("utils.zig");
const wl = wayland.server.wl;
const mez = wayland.server.zmez;

const gpa = std.heap.c_allocator;
const server = &@import("main.zig").server;
const Lua = &@import("main.zig").lua;

id: usize,
remote_lua_v1: *mez.RemoteLuaV1,

pub fn sendNewLogEntry(str: [*:0]const u8) void {
  for (server.remote_lua_clients.items) |c| {
    c.remote_lua_v1.sendNewLogEntry(str);
  }
}

pub fn create(client: *wl.Client, version: u32, id: u32) !void {
  const remote_lua_v1 = try mez.RemoteLuaV1.create(client, version, id);

  const node = try gpa.create(RemoteLua);
  errdefer gpa.destroy(node);
  node = .{
    .remote_lua_v1 = remote_lua_v1,
    .id = server.remote_lua_clients.items.len,
  };
  server.remote_lua_clients.append(gpa, node);

  remote_lua_v1.setHandler(*RemoteLua, handleRequest, handleDestroy, &node);
}

fn handleRequest(
remote_lua_v1: *mez.RemoteLuaV1,
request: mez.RemoteLuaV1.Request,
_: *RemoteLua,
) void {
  switch (request) {
    .destroy => remote_lua_v1.destroy(),
    .push_lua => |req| {
      Lua.state.loadString(req.lua_chunk) catch {
        const errTxt: []const u8 = Lua.state.toString(-1) catch unreachable;
        try sendNewLogEntry("repl: " ++ errTxt);
      };
    },
  }
}

fn handleDestroy(_: *mez.RemoteLuaV1, remote_lua: *RemoteLua) void {
  server.remote_lua_clients.swapRemove(remote_lua.id);
  gpa.destroy(remote_lua);
}
