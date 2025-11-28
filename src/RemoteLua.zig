const RemoteLua = @This();

const std = @import("std");
const wayland = @import("wayland");
const Utils = @import("utils.zig");
const Lua = @import("lua/lua.zig");
const wl = wayland.server.wl;
const mez = wayland.server.zmez;

const gpa = std.heap.c_allocator;
const server = &@import("main.zig").server;

id: usize,
remote_lua_v1: *mez.RemoteLuaV1,
L: Lua,

pub fn sendNewLogEntry(str: [*:0]const u8) void {
  for (server.remote_lua_clients.items) |c| {
    c.remote_lua_v1.sendNewLogEntry(str);
  }
}

pub fn create(client: *wl.Client, version: u32, id: u32) !void {
  const remote_lua_v1 = try mez.RemoteLuaV1.create(client, version, id);

  const node = try gpa.create(RemoteLua);
  errdefer gpa.destroy(node);
  node.* = .{
    .remote_lua_v1 = remote_lua_v1,
    .id = server.remote_lua_clients.items.len,
    .L = undefined,
  };
  try node.L.init();
  errdefer node.L.deinit();
  try server.remote_lua_clients.append(gpa, node);

  remote_lua_v1.setHandler(*RemoteLua, handleRequest, handleDestroy, node);
}

fn handleRequest(
remote_lua_v1: *mez.RemoteLuaV1,
request: mez.RemoteLuaV1.Request,
remote: *RemoteLua,
) void {
  switch (request) {
    .destroy => remote_lua_v1.destroy(),
    .push_lua => |req| {
      const chunk = std.mem.sliceTo(req.lua_chunk, 0);
      remote.L.state.loadString(chunk) catch catchLuaFail(remote);
      remote.L.state.protectedCall(.{}) catch catchLuaFail(remote);
    },
  }
}

fn catchLuaFail(remote: *RemoteLua) void {
  const err_txt: []const u8 = remote.L.state.toString(-1) catch unreachable;
  const txt = std.mem.concat(gpa, u8, &[_][]const u8{ "repl: ", err_txt }) catch Utils.oomPanic();
  defer gpa.free(txt);

  // must add the sentinel back to pass the data over the wire
  const w_sentinel = gpa.allocSentinel(u8, txt.len, 0) catch Utils.oomPanic();
  defer gpa.free(w_sentinel);
  std.mem.copyForwards(u8, w_sentinel, txt[0..txt.len]);

  sendNewLogEntry(w_sentinel);
  return;
}

fn handleDestroy(_: *mez.RemoteLuaV1, remote_lua: *RemoteLua) void {
  _ = server.remote_lua_clients.swapRemove(remote_lua.id);
  remote_lua.L.deinit();
  gpa.destroy(remote_lua);
}
