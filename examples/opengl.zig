const std = @import("std");
const zigwin = @import("zigwin");

const Platform = zigwin.Platform(.{
    .hdr = false,
    .wayland = false,
    .x11 = true,
    .render_opengl = true,
    .render_vulkan = false,
    .render_software = true,
    .x11_use_xlib = true,
});

pub fn main() !void {
    var platform = try Platform.init();
    defer platform.deinit();

    var context = try platform.createOpenGLContext(.{ .major = 3, .minor = 3, .core = false, .forward_compatible = false, .debug = true }, null);
    defer context.deinit();

    var window: Platform.Window = undefined;
    try platform.createWindow(&window, .{ .title = "Zigwin OpenGL Example", .opengl_context_compatible = &context });
    defer window.deinit();

    try context.makeCurrent(&window);
    context.setSwapInterval(1);

    try initOpenGLStuff();

    while (true) {
        while (true) {
            const event = (try platform.pollForEvent()) orelse break;
            defer platform.freeEvent(event);
            switch (event) {
                .window_resized => |win| {
                    c.glViewport(0, 0, window.width, window.height);
                },
                .window_destroyed => return,
                .platform_terminated => return,
                else => {},
            }
        }
        try renderOpenGLStuff();
        context.swapBuffers(window);
    }
}

// The OpenGL code follows, not relevant to the use of the library itself
// TODO: Fix legacy GL crap

const c = @cImport({
    @cInclude("GL/gl.h");
});

fn initOpenGLStuff() !void {
    c.glClearColor(0.0, 0.0, 0.0, 0.0);
}

fn renderOpenGLStuff() !void {
    c.glClear(c.GL_COLOR_BUFFER_BIT);
    c.glBegin(c.GL_TRIANGLES);
    c.glColor3f(0.25, 0.5, 0.75);
    c.glVertex3f(-0.5, -0.5, 0);
    c.glVertex3f(0, 0.5, 0);
    c.glVertex3f(0.5, -0.5, 0);
    c.glEnd();

    const err = c.glGetError();
    if (err != 0) std.log.err("{}", .{err});
}
