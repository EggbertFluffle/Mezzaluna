const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

// server owns
//   - compositor
//
// wlr_compositor owms
//   - a list of wlr_surfaces
//
// wlr_surfaces own_buffers
//
// struct wl_resource *_surface;
//         wl_resource_for_each(_surface, &server->compositor->surfaces) {
//                 struct wlr_surface *surface = wlr_surface_from_resource(_surface);
//                 if (!wlr_surface_has_buffer(surface)) {
//                         continue;
//                 }
//                 struct wlr_box render_box = {
//                         .x = 20, .y = 20,
//                         .width = surface->current->width,
//                         .height = surface->current->height
//                 };
//                 float matrix[16];
//                 wlr_matrix_project_box(&matrix, &render_box,
//                                 surface->current->transform,
//                                 0, &wlr_output->transform_matrix);
//                wlr_render_with_matrix(renderer, surface->texture, &matrix, 1.0f);
//                wlr_surface_send_frame_done(surface, &now);
//         }
//
//
//
// wlr_scene owns
//   - list of outputs
//   - wlr_scene_tree
//
// wlr_scene_tree owns
//   - its own wlr_scene_node
//   - list of its children wlr_scene_node
//
// wlr_scene_node can be TREE, RECT or BUFFER and owns
//   - its own type
//   - a pointer to its parent wlr_scene_tree
//   - a list of children as wlr_scene_trees
//   - boolean if enabled
//   - x, y position relative to parent
//   - wl signal for destroy
//   - *void arbitrary data


