const LayerSurface = @This();

const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Utils = @import("Utils.zig");
const Output = @import("Output.zig");

const gpa = std.heap.c_allocator;
const server = &@import("main.zig").server;

output: *Output,
wlr_layer_surface: *wlr.LayerSurfaceV1,
scene_layer_surface: *wlr.SceneLayerSurfaceV1,

destroy: wl.Listener(*wlr.LayerSurfaceV1) = .init(handleDestroy),
map: wl.Listener(void) = .init(handleMap),
unmap: wl.Listener(void) = .init(handleUnmap),
commit: wl.Listener(*wlr.Surface) = .init(handleCommit),
// new_popup: wl.Listener(*wlr.XdgPopup) = wl.Listener(*wlr.XdgPopup).init(handleNewPopup),

pub fn init(wlr_layer_surface: *wlr.LayerSurfaceV1) *LayerSurface {
  errdefer Utils.oomPanic();

  const self = try gpa.create(LayerSurface);

  self.* = .{
    .output = @ptrCast(@alignCast(wlr_layer_surface.output.?.data)),
    .wlr_layer_surface = wlr_layer_surface,
    .scene_layer_surface = undefined,
  };

  if(server.seat.focused_output) |output| {
    self.scene_layer_surface = switch (wlr_layer_surface.current.layer) {
      .background => try output.layers.background.createSceneLayerSurfaceV1(wlr_layer_surface),
      .bottom => try output.layers.bottom.createSceneLayerSurfaceV1(wlr_layer_surface),
      .top => try output.layers.top.createSceneLayerSurfaceV1(wlr_layer_surface),
      .overlay => try output.layers.overlay.createSceneLayerSurfaceV1(wlr_layer_surface),
      else => {
        std.log.err("New layer surface of unidentified type", .{});
        unreachable;
      }
    };
  }

  self.wlr_layer_surface.surface.data = &self.scene_layer_surface.tree.node;

  self.wlr_layer_surface.events.destroy.add(&self.destroy);
  self.wlr_layer_surface.surface.events.map.add(&self.map);
  self.wlr_layer_surface.surface.events.unmap.add(&self.unmap);
  self.wlr_layer_surface.surface.events.commit.add(&self.commit);

  return self;
}

pub fn deinit(self: *LayerSurface) void {
  self.destroy.link.remove();
  self.map.link.remove();
  self.unmap.link.remove();
  self.commit.link.remove();

  self.wlr_layer_surface.surface.data = null;

  gpa.destroy(self);
}

fn handleDestroy(
  listener: *wl.Listener(*wlr.LayerSurfaceV1),
  _: *wlr.LayerSurfaceV1
) void {
  const layer: *LayerSurface = @fieldParentPtr("destroy", listener);
  layer.deinit();
}

fn handleMap(
  _: *wl.Listener(void)
) void {
  std.log.debug("Unimplemented layer surface map", .{});
}

fn handleUnmap(
  _: *wl.Listener(void)
) void {
  std.log.debug("Unimplemented layer surface unmap", .{});
}

fn handleCommit(
  listener: *wl.Listener(*wlr.Surface),
  _: *wlr.Surface
) void {
  const layer_surface: *LayerSurface = @fieldParentPtr("commit", listener);

  var width: c_int = undefined;
  var height: c_int = undefined;
  layer_surface.output.wlr_output.effectiveResolution(&width, &height);
  _ = layer_surface.wlr_layer_surface.configure(@intCast(width), @intCast(height));

  layer_surface.scene_layer_surface.tree.node.reparent(layer_surface.output.layers.background);
}
