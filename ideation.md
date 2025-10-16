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
* Selene
* Chandra - wtf
* Phoeb - Horrible to write in code
* Mezzaluna (mez)
* Gibbous (gib)
* Monzonite (monz)
* Slasagna

# Style Guide

Perhaps we do what river does for organization? Checkout river/Server.zig:17's use of @This();
