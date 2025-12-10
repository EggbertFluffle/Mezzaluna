const RemoteLua = @This();

const std = @import("std");
const zlua = @import("zlua");
const wayland = @import("wayland");
const Utils = @import("utils.zig");
const Lua = @import("lua/lua.zig");
const wl = wayland.server.wl;
const mez = wayland.server.zmez;

const gpa = std.heap.c_allocator;
const server = &@import("main.zig").server;

node: std.DoublyLinkedList.Node,
remote_lua_v1: *mez.RemoteLuaV1,
L: *zlua.Lua,

pub fn sendNewLogEntry(str: [*:0]const u8) void {
  var node = server.remote_lua_clients.first;
  while (node) |n| {
    const data: ?*RemoteLua = @fieldParentPtr("node", n);
    if (data) |d| d.remote_lua_v1.sendNewLogEntry(str);
    node = n.next;
  }
}

pub fn create(client: *wl.Client, version: u32, id: u32) !void {
  const remote_lua_v1 = try mez.RemoteLuaV1.create(client, version, id);

  const node = try gpa.create(RemoteLua);
  errdefer gpa.destroy(node);
  node.* = .{
    .remote_lua_v1 = remote_lua_v1,
    .node = .{},
    .L = try zlua.Lua.init(gpa),
  };
  errdefer node.L.deinit();
  node.L.openLibs();
  Lua.openLibs(node.L);
  // TODO: replace stdout and stderr with buffers we can send to the clients

  server.remote_lua_clients.prepend(&node.node);

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
      // TODO: this could be a lot smarter, we don't want to add return to a
      // statement which already has return infront of it.
      const str = std.mem.concatWithSentinel(gpa, u8, &[_][]const u8{ "return ", chunk }, 0) catch return catchLuaFail(remote);
      defer gpa.free(str);

      remote.L.loadString(str) catch catchLuaFail(remote);
      remote.L.protectedCall(.{
        .results = zlua.mult_return,
      }) catch catchLuaFail(remote);

      var i: i32 = 1;
      while (i < remote.L.getTop() + 1) : (i += 1) {
        sendNewLogEntry(remote.L.toString(-1) catch return catchLuaFail(remote));
        remote.L.pop(-1);
      }
    },
  }
}

fn handleDestroy(_: *mez.RemoteLuaV1, remote_lua: *RemoteLua) void {
  if (remote_lua.node.prev) |p| {
    if (remote_lua.node.next) |n| n.prev.? = p;
    p.next = remote_lua.node.next;
  } else server.remote_lua_clients.first = remote_lua.node.next;

  remote_lua.L.deinit();
  gpa.destroy(remote_lua);
}

fn catchLuaFail(remote: *RemoteLua) void {
  const err_txt: []const u8 = remote.L.toString(-1) catch "zig error";
  const txt = std.mem.concatWithSentinel(gpa, u8, &[_][]const u8{ "repl: ", err_txt }, 0) catch Utils.oomPanic();
  defer gpa.free(txt);

  sendNewLogEntry(txt);
  return;
}
