const View = @import("View.zig");
const LayerSurface = @import("LayerSurface.zig");
const Output = @import("Output.zig");

const SceneNodeType = enum { view, layer_surface, output };
pub const SceneNodeData = union(SceneNodeType) {
  view: *View,
  layer_surface: *LayerSurface,
  output: *Output
};
