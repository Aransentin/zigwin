const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("example", "example/example.zig");
    exe.addPackagePath("zigwin", "src/zigwin.zig");
    exe.single_threaded = true;
    exe.subsystem = .Windows;
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkLibC();
    exe.linkSystemLibrary("OpenGL");
    if (mode == .ReleaseSmall) {
        exe.strip = true;
    }
    exe.install();

    const exe_cmd = exe.run();
    const exe_step = b.step("run", "Run the example application");
    exe_step.dependOn(&exe_cmd.step);
}
