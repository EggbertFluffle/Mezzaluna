const Output = @This();

const wl = @import("wayland").server.wl;
const zwlr = @import("wayland").server.zwlr;
const wlr = @import("wlroots");
const std = @import("std");



const Server = @import("Server.zig");
const Utils =  @import("Utils.zig");
const View =   @import("View.zig");

const posix = std.posix;
const gpa = std.heap.c_allocator;
const server = &@import("main.zig").server;

focused: bool,
id: u64,

wlr_output: *wlr.Output,
state: wlr.Output.State,
tree: *wlr.SceneTree,
scene_output: *wlr.SceneOutput,

layers: struct {
  background: *wlr.SceneTree,
  bottom: *wlr.SceneTree,
  content: *wlr.SceneTree,
  top: *wlr.SceneTree,
  fullscreen: *wlr.SceneTree,
  overlay: *wlr.SceneTree
},

frame: wl.Listener(*wlr.Output) = .init(handleFrame),
request_state: wl.Listener(*wlr.Output.event.RequestState) = .init(handleRequestState),
destroy: wl.Listener(*wlr.Output) = .init(handleDestroy),


// The wlr.Output should be destroyed by the caller on failure to trigger cleanup.
pub fn init(wlr_output: *wlr.Output) ?*Output {
  errdefer Utils.oomPanic();

  const self = try gpa.create(Output);

  self.* = .{
    .focused = false,
    .id = @intFromPtr(wlr_output),
    .wlr_output = wlr_output,
    .tree = try server.root.scene.tree.createSceneTree(),
    .layers = .{
      .background = try self.tree.createSceneTree(),
      .bottom = try self.tree.createSceneTree(),
      .content = try self.tree.createSceneTree(),
      .top = try self.tree.createSceneTree(),
      .fullscreen = try self.tree.createSceneTree(),
      .overlay = try self.tree.createSceneTree(),
    },
    .scene_output = try server.root.scene.createSceneOutput(wlr_output),
    .state = wlr.Output.State.init()
  };

  wlr_output.events.frame.add(&self.frame);
  wlr_output.events.request_state.add(&self.request_state);
  wlr_output.events.destroy.add(&self.destroy);

  errdefer deinit(self);

  if(!wlr_output.initRender(server.allocator, server.renderer)) {
    std.log.err("Unable to start output {s}", .{wlr_output.name});
    return null;
  }

  self.state.setEnabled(true);

  if (wlr_output.preferredMode()) |mode| {
    self.state.setMode(mode);
  }

  if(!wlr_output.commitState(&self.state)) {
    std.log.err("Unable to commit state to output {s}", .{wlr_output.name});
    return null;
  }

  const layout_output = try server.root.output_layout.addAuto(self.wlr_output);
  server.root.scene_output_layout.addOutput(layout_output, self.scene_output);
  self.setFocused();

  wlr_output.data = self;

  return self;
}

pub fn deinit(self: *Output) void {
  self.frame.link.remove();
  self.request_state.link.remove();
  self.destroy.link.remove();

  self.state.finish();

  self.wlr_output.destroy();

  gpa.destroy(self);
}

pub fn setFocused(self: *Output) void {
  if(server.seat.focused_output) |prev_output| {
    prev_output.focused = false;
  }

  server.seat.focused_output = self;
  self.focused = true;
}

pub fn configureLayers(self: *Output) void {
  var output_box: wlr.Box = .{
    .x = 0,
    .y = 0,
    .width = undefined,
    .height = undefined,
  };
  self.wlr_output.effectiveResolution(&output_box.width, &output_box.height);

  // Should calculate usable area here for LUA view positioning

  for ([_]zwlr.LayerShellV1.Layer{ .background, .bottom, .top, .overlay }) |layer| {
    const tree = blk: {
      const trees = [_]*wlr.SceneTree{
          self.layers.background,
          self.layers.bottom,
          self.layers.top,
          self.layers.overlay,
      };
      break :blk trees[@intCast(@intFromEnum(layer))];
    };

    var it = tree.children.iterator(.forward);
    while(it.next()) |node| {
      if(node.data == null) continue;

      const layer_surface: *wlr.LayerSurfaceV1 = @ptrCast(@alignCast(node.data.?));
      _ = layer_surface.configure(@intCast(output_box.width), @intCast(output_box.height));
    }
  }
}

const ViewAtResult = struct {
    view: *View,
    surface: *wlr.Surface,
    sx: f64,
    sy: f64,
};

pub fn viewAt(self: *Output, lx: f64, ly: f64) ?ViewAtResult {
  var sx: f64 = undefined;
  var sy: f64 = undefined;

  if(self.layers.content.node.at(lx, ly, &sx, &sy)) |node| {
    if (node.type != .buffer) return null;
    const scene_buffer = wlr.SceneBuffer.fromNode(node);
    const scene_surface = wlr.SceneSurface.tryFromBuffer(scene_buffer) orelse return null;

    var it: ?*wlr.SceneTree = node.parent;

    while (it) |n| : (it = n.node.parent) {
      if (n.node.data == null) continue;

      const view: *View = @ptrCast(@alignCast(n.node.data.?));

      return ViewAtResult{
        .view = view,
        .surface = scene_surface.surface,
        .sx = sx,
        .sy = sy,
      };
    }
  }
  return null;
}

// --------- WlrOutput Event Handlers ---------
fn handleRequestState(
  listener: *wl.Listener(*wlr.Output.event.RequestState),
  event: *wlr.Output.event.RequestState,
) void {
  const output: *Output = @fieldParentPtr("request_state", listener);

  if (!output.wlr_output.commitState(event.state)) {
    std.log.warn("failed to set output state {}", .{event.state});
  }
}

fn handleFrame(
  _: *wl.Listener(*wlr.Output),
  wlr_output: *wlr.Output
) void {
  const scene_output = server.root.scene.getSceneOutput(wlr_output);

  if(scene_output == null) {
    std.log.err("Unable to get scene output to render", .{});
    return;
  }

  // std.log.info("Rendering commited scene output\n", .{});
  _ = scene_output.?.commit(null);

  var now = posix.clock_gettime(posix.CLOCK.MONOTONIC) catch @panic("CLOCK_MONOTONIC not supported");
  scene_output.?.sendFrameDone(&now);
}

fn handleDestroy(
  listener: *wl.Listener(*wlr.Output),
  _: *wlr.Output
) void {
  std.log.debug("Handling destroy", .{});
  const output: *Output = @fieldParentPtr("destroy", listener);

  std.log.debug("removing output: {s}", .{output.wlr_output.name});

  output.frame.link.remove();
  output.request_state.link.remove();
  output.destroy.link.remove();

  server.root.output_layout.remove(output.wlr_output);

  gpa.destroy(output);
}
