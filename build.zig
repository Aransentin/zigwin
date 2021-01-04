const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    // Software rendering

    // OpenGL
    const ogl = b.addExecutable("opengl", "examples/opengl.zig");
    ogl.addPackagePath("zigwin", "src/zigwin.zig");
    ogl.single_threaded = true;
    ogl.subsystem = .Windows;
    ogl.setTarget(target);
    ogl.setBuildMode(mode);
    ogl.linkLibC();
    ogl.linkSystemLibrary("OpenGL");
    ogl.install();

    const ogl_cmd = ogl.run();
    const ogl_step = b.step("opengl", "Run the OpenGL example application");
    ogl_step.dependOn(&ogl_cmd.step);
}
