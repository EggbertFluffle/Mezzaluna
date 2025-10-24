pub const c = @cImport({
    @cInclude("linux/input-event-codes.h");
    @cInclude("libevdev/libevdev.h");
    @cInclude("libinput.h");
});
