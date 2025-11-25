# {NAME GOES HERE}
1. Not strictly dynamic tiling, calls to a lua script (a standard stack/master by default) to know where to
    * Tile windows
    * Follow window rules, (GIMP should be floating)
    * If this is the case, a default config should exist somewhere
2. A very transparent API for lua to interact with is important
    * I love the idea of the autocommands, wm should hold a callback list for each autocommand (maybe look at how nvim does this)
3. Is it better to use the zig-wlroots bindings, "translate-c" wlroots, or compile the C in with wlroots
    * It seems like Isaac started with translate-c and then created the wlroots bindings. Depends if we want latest for wlroots and zig
    * Not using the bindings is most likey a LOT of extra work

# Names
* Mezzaluna (mez)

# Style Guide

Perhaps we do what river does for organization? Checkout river/Server.zig:17's use of @This();

# information

server owns
- compositor

wlr_compositor owms
- a list of wlr_surfaces

wlr_surfaces owns
- wl_resources which should (be/have?) buffers

## Scene Structure
wlr_scene owns
- list of outputs
- wlr_scene_tree

wlr_scene_tree owns
- its own wlr_scene_node
- list of its children wlr_scene_node

wlr_scene_node can be TREE, RECT or BUFFER and owns
- its own type
- a pointer to its parent wlr_scene_tree
- a list of children as wlr_scene_trees
- boolean if enabled
- x, y position relative to parent
- wl signal for destroy
- *void arbitrary data

```zig
struct wl_resource *_surface;

wl_resource_for_each(_surface, &server->compositor->surfaces) {
    struct wlr_surface *surface = wlr_surface_from_resource(_surface);
    if (!wlr_surface_has_buffer(surface)) {
        continue;
    }

    struct wlr_box render_box = {
        .x = 20, .y = 20,
        .width = surface->current->width,
        .height = surface->current->height
    };

    float matrix[16];
    wlr_matrix_project_box(&matrix, &render_box,
    surface->current->transform,
    0, &wlr_output->transform_matrix);
    wlr_render_with_matrix(renderer, surface->texture, &matrix, 1.0f);
    wlr_surface_send_frame_done(surface, &now);
}
```
