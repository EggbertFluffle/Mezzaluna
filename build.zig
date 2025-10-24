const std = @import("std");
const builtin = @import("builtin");

const Scanner = @import("wayland").Scanner;

pub fn build(b: *std.Build) void {
  const target = b.standardTargetOptions(.{});
  const optimize = b.standardOptimizeOption(.{});

  // TODO: this will probably change based on the install paths, make this a var
  // that can be passed at comptime?
  const runtime_path_prefix = switch (builtin.mode) {
    .Debug => "runtime/",
    else => "/usr/share",
  };

  // If instead your goal is to create an executable, consider if users might
  // be interested in also being able to embed the core functionality of your
  // program in their own executable in order to avoid the overhead involved in
  // subprocessing your CLI tool.

  // The below is copied from tinywl
  // TODO: Ensure versioning is correct
  // TODO: Ensure paths for system protocols are correct
  const scanner = Scanner.create(b, .{});
  scanner.addSystemProtocol("stable/xdg-shell/xdg-shell.xml");
  scanner.addSystemProtocol("stable/tablet/tablet-v2.xml");
  scanner.addSystemProtocol("unstable/xdg-decoration/xdg-decoration-unstable-v1.xml");

  scanner.generate("wl_compositor", 6);
  scanner.generate("wl_subcompositor", 1);
  scanner.generate("wl_shm", 1);
  scanner.generate("wl_output", 4);
  scanner.generate("wl_seat", 7);
  scanner.generate("wl_data_device_manager", 3);
  scanner.generate("zxdg_decoration_manager_v1", 1);
  scanner.generate("xdg_wm_base", 2);
  scanner.generate("zwp_tablet_manager_v2", 1);

  const wayland = b.createModule(.{ .root_source_file = scanner.result });
  const xkbcommon = b.dependency("xkbcommon", .{}).module("xkbcommon");
  const pixman = b.dependency("pixman", .{}).module("pixman");
  const wlroots = b.dependency("wlroots", .{}).module("wlroots");
  const zlua = b.dependency("zlua", .{}).module("zlua");

  wlroots.addImport("wayland", wayland);
  wlroots.addImport("xkbcommon", xkbcommon);
  wlroots.addImport("pixman", pixman);

  wlroots.resolved_target = target;
  wlroots.linkSystemLibrary("wlroots-0.19", .{});

  const mez = b.addExecutable(.{
    .name = "mez",
    .root_module = b.createModule(.{
      .root_source_file = b.path("src/main.zig"),
      .target = target,
      .optimize = optimize,
    }),
  });

  mez.linkLibC();

  mez.root_module.addImport("wayland", wayland);
  mez.root_module.addImport("xkbcommon", xkbcommon);
  mez.root_module.addImport("wlroots", wlroots);
  mez.root_module.addImport("zlua", zlua);

  mez.linkSystemLibrary("wayland-server");
  mez.linkSystemLibrary("xkbcommon");
  mez.linkSystemLibrary("pixman-1");

  const options = b.addOptions();
  options.addOption([]const u8, "runtime_path_prefix", runtime_path_prefix);
  mez.root_module.addOptions("config", options);

  b.installArtifact(mez);

  const run_step = b.step("run", "Run the app");
  const run_cmd = b.addRunArtifact(mez);
  run_step.dependOn(&run_cmd.step);
  run_cmd.step.dependOn(b.getInstallStep());
  run_cmd.addArg("weston-terminal");
}
