const std = @import("std");
const builtin = @import("builtin");
usingnamespace @import("bits.zig");
const zigwin = @import("../zigwin.zig");

var libgl: ?*c_void = null;
fn getLibGL() !*c_void {
    if (libgl) |lib| return lib;
    if (std.c.dlopen("libGL.so", std.c.RTLD_NOW | std.c.RTLD_LOCAL)) |lib| {
        libgl = lib;
        return lib;
    } else return error.GLLibraryNotFound;
}

var libogl: ?*c_void = null;
fn getLibOpenGL() !*c_void {
    if (libogl) |lib| return lib;
    if (std.c.dlopen("libOpenGL.so", std.c.RTLD_NOW | std.c.RTLD_LOCAL)) |lib| {
        libogl = lib;
        return lib;
    } else return error.OpenGlLibraryNotFound;
}

var libglx: ?*c_void = null;
fn getLibGLX() !*c_void {
    if (libglx) |lib| return lib;
    if (std.c.dlopen("libGLX.so", std.c.RTLD_NOW | std.c.RTLD_LOCAL)) |lib| {
        libglx = lib;
        return lib;
    } else return error.GLXibraryNotFound;
}

var libegl: ?*c_void = null;
fn getLibEGL() !*c_void {
    if (libegl) |lib| return lib;
    if (std.c.dlopen("libEGL.so", std.c.RTLD_NOW | std.c.RTLD_LOCAL)) |lib| {
        libegl = lib;
        return lib;
    } else return error.EGLLibraryNotFound;
}

pub fn libraryCleanup() void {
    if (libegl) |lib| _ = std.c.dlclose(lib);
    if (libglx) |lib| _ = std.c.dlclose(lib);
    if (libogl) |lib| _ = std.c.dlclose(lib);
    if (libgl) |lib| _ = std.c.dlclose(lib);
    libegl = null;
    libglx = null;
    libogl = null;
    libgl = null;
}

const GLXContext = opaque {};
pub const GLXFBConfig = opaque {};
pub const GLXWindow = u32;

const XVisualInfo = extern struct {
    visual: *c_void,
    visualid: c_ulong,
    screen: c_int,
    depth: c_int,
    class: c_int,
    red_mask: c_ulong,
    green_mask: c_ulong,
    blue_mask: c_ulong,
    colormap_size: c_int,
    bits_per_rgb: c_int,
};

fn loadsym(comptime T: type, lib: *c_void, symbol: [*:0]const u8) !T {
    const fpopt = std.c.dlsym(lib, symbol);
    if (fpopt) |fp| {
        return @ptrCast(T, fp);
    } else return error.SymbolNotFound;
}

const GlXGetProcAddressARB = fn ([*:0]const u8) callconv(.C) ?*c_void;
const GlXChooseFBConfig = fn (*Display, c_int, [*]const c_int, *c_int) callconv(.C) ?[*]*GLXFBConfig;
const GlXCreateContextAttribsARB = fn (*Display, *GLXFBConfig, ?*GLXContext, c_int, ?[*]const c_int) callconv(.C) *GLXContext;
const GlXGetVisualFromFBConfig = fn (*Display, *GLXFBConfig) callconv(.C) *XVisualInfo;
const GlXMakeContextCurrent = fn (*Display, GLXWindow, GLXWindow, ?*GLXContext) callconv(.C) c_int;
const GlXDestroyContext = fn (*Display, *GLXContext) callconv(.C) void;
const GlXSwapIntervalEXT = fn (*Display, GLXWindow, c_int) callconv(.C) void;
const GlXSwapBuffers = fn (*Display, GLXWindow) callconv(.C) void;
const GlXCreateWindow = fn (*Display, *GLXFBConfig, WINDOW, ?[*]const c_int) callconv(.C) GLXWindow;
const GlXDestroyWindow = fn (*Display, GLXWindow) callconv(.C) void;

var glXMakeContextCurrent: GlXMakeContextCurrent = undefined;
var glXDestroyContext: GlXDestroyContext = undefined;
var glXSwapIntervalEXT: GlXSwapIntervalEXT = undefined;
var glXSwapBuffers: GlXSwapBuffers = undefined;
var glXCreateWindow: GlXCreateWindow = undefined;
pub var glXDestroyWindow: GlXDestroyWindow = undefined;

const GLX_USE_GL = 1;
const GLX_BUFFER_SIZE = 2;
const GLX_LEVEL = 3;
const GLX_RGBA = 4;
const GLX_DOUBLEBUFFER = 5;
const GLX_STEREO = 6;
const GLX_AUX_BUFFERS = 7;
const GLX_RED_SIZE = 8;
const GLX_GREEN_SIZE = 9;
const GLX_BLUE_SIZE = 10;
const GLX_ALPHA_SIZE = 11;
const GLX_DEPTH_SIZE = 12;
const GLX_STENCIL_SIZE = 13;
const GLX_ACCUM_RED_SIZE = 14;
const GLX_ACCUM_GREEN_SIZE = 15;
const GLX_ACCUM_BLUE_SIZE = 16;
const GLX_ACCUM_ALPHA_SIZE = 17;
const GLX_X_VISUAL_TYPE = 0x22;
const GLX_TRANSPARENT_TYPE = 0x23;
const GLX_X_RENDERABLE = 0x8012;
const GLX_FRAMEBUFFER_SRGB_CAPABLE_ARB = 0x20B2;
const GLX_SAMPLES = 100001;

const GLX_NONE = 0x8000;
const GLX_TRUE_COLOR = 0x8002;
const GLX_TRANSPARENT_RGB = 0x8008;

const GLX_CONTEXT_MAJOR_VERSION_ARB = 0x2091;
const GLX_CONTEXT_MINOR_VERSION_ARB = 0x2092;
const GLX_CONTEXT_FLAGS_ARB = 0x2094;
const GLX_CONTEXT_PROFILE_MASK_ARB = 0x9126;

const GLX_CONTEXT_DEBUG_BIT_ARB = 0x0001;
const GLX_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB = 0x0002;

const GLX_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001;
const GLX_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB = 0x00000002;

fn loadsymGLX(comptime T: type, loader: GlXGetProcAddressARB, symbol: [*:0]const u8) !T {
    const fpopt = loader(symbol);
    if (fpopt) |fp| {
        return @ptrCast(T, fp);
    } else return error.SymbolNotFound;
}

const ContextType = enum {
    glx,
    egl,
};

pub fn Context(comptime Platform: anytype) type {
    return struct {
        const Self = @This();
        platform: *Platform,
        visual: VISUALID = undefined,
        visual_depth: u8 = undefined,

        backend: union(ContextType) {
            glx: struct {
                context: *GLXContext,
                configurations: [*]*GLXFBConfig,
            },
            egl: u32,
        } = undefined,

        pub fn init(platform: *Platform, options: zigwin.OpenGLContextOptions, share: ?*Self) !Self {
            var self = Self{
                .platform = platform,
            };

            if (options.egl) {
                try self.initEGL();
            } else {
                const sharedctx = if (share != null) share.?.backend.glx.context else null;
                try self.initGLX(options, sharedctx);
            }

            return self;
        }

        pub fn initGLX(self: *Self, options: zigwin.OpenGLContextOptions, share: ?*GLXContext) !void {
            const lib_gpa = if (options.linux_glvnd) try getLibGLX() else try getLibGL();
            const glXGetProcAddressARB = try loadsym(GlXGetProcAddressARB, lib_gpa, "glXGetProcAddressARB");
            const glXChooseFBConfig = try loadsym(GlXChooseFBConfig, lib_gpa, "glXChooseFBConfig");
            const glXCreateContextAttribsARB = try loadsymGLX(GlXCreateContextAttribsARB, glXGetProcAddressARB, "glXCreateContextAttribsARB");
            const glXGetVisualFromFBConfig = try loadsymGLX(GlXGetVisualFromFBConfig, glXGetProcAddressARB, "glXGetVisualFromFBConfig");

            // TODO: glXQueryVersion
            // TODO: glXQueryExtensionsString

            glXMakeContextCurrent = try loadsymGLX(GlXMakeContextCurrent, glXGetProcAddressARB, "glXMakeContextCurrent");
            glXDestroyContext = try loadsymGLX(GlXDestroyContext, glXGetProcAddressARB, "glXDestroyContext");
            glXSwapIntervalEXT = try loadsymGLX(GlXSwapIntervalEXT, glXGetProcAddressARB, "glXSwapIntervalEXT");
            glXSwapBuffers = try loadsymGLX(GlXSwapBuffers, glXGetProcAddressARB, "glXSwapBuffers");
            glXCreateWindow = try loadsymGLX(GlXCreateWindow, glXGetProcAddressARB, "glXCreateWindow");
            glXDestroyWindow = try loadsymGLX(GlXDestroyWindow, glXGetProcAddressARB, "glXDestroyWindow");

            const attribs = [_][2]c_int{
                .{ GLX_X_RENDERABLE, 1 },
                .{ GLX_DOUBLEBUFFER, 1 },
                .{ GLX_RED_SIZE, 1 },
                .{ GLX_GREEN_SIZE, 1 },
                .{ GLX_BLUE_SIZE, 1 },
                .{ GLX_ALPHA_SIZE, options.alpha_bits },
                .{ GLX_DEPTH_SIZE, options.depth_bits },
                .{ GLX_STENCIL_SIZE, options.stencil_bits },
                .{ GLX_X_VISUAL_TYPE, GLX_TRUE_COLOR },
                .{ GLX_FRAMEBUFFER_SRGB_CAPABLE_ARB, if (options.srgb) 1 else 0 },
                .{ GLX_TRANSPARENT_TYPE, if (options.transparent) GLX_TRANSPARENT_RGB else GLX_NONE },
                .{ GLX_SAMPLES, options.samples },
                .{ 0, 0 },
            };

            var configurations_n: c_int = 0;
            var configurations = glXChooseFBConfig(self.platform.display, self.platform.screen_id, @ptrCast([*]const c_int, &attribs), &configurations_n) orelse return error.glXChooseFBConfigFailed;
            errdefer xFree(@ptrCast(*c_void, configurations));
            if (configurations_n == 0) {
                return error.NoValidConfigurations;
            }
            const configuration = configurations[0];

            var visual = glXGetVisualFromFBConfig(self.platform.display, configuration);
            defer xFree(@ptrCast(*c_void, visual));
            self.visual = @intCast(u32, visual.visualid);
            self.visual_depth = @intCast(u8, visual.depth);

            var context_flags: c_int = 0;
            if (options.debug) context_flags |= GLX_CONTEXT_DEBUG_BIT_ARB;
            if (options.forward_compatible) context_flags |= GLX_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB;

            const ctx_attribs = [_][2]c_int{
                .{ GLX_CONTEXT_MAJOR_VERSION_ARB, options.major },
                .{ GLX_CONTEXT_MINOR_VERSION_ARB, options.minor },
                .{ GLX_CONTEXT_FLAGS_ARB, context_flags },
                .{ GLX_CONTEXT_PROFILE_MASK_ARB, if (options.core) GLX_CONTEXT_CORE_PROFILE_BIT_ARB else GLX_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB },
                .{ 0, 0 },
            };

            const context = glXCreateContextAttribsARB(self.platform.display, configuration, share, 1, @ptrCast([*]const c_int, &ctx_attribs));
            self.backend = .{ .glx = .{ .context = context, .configurations = configurations } };
        }

        pub fn initEGL(self: *Self) !void {
            // TODO
        }

        pub fn deinit(self: *Self) void {
            switch (self.backend) {
                .glx => |glx| {
                    std.log.debug("glXDestroyContext: {x}", .{glx.context});
                    xFree(@ptrCast(*c_void, glx.configurations));
                    glXDestroyContext(self.platform.display, glx.context);
                },
                .egl => |egl| undefined,
            }
        }

        pub fn makeCurrent(self: *Self, window: *Platform.Window) !void {
            switch (self.backend) {
                .glx => |glx| {
                    if (window.glx_window == 0) {
                        window.glx_window = glXCreateWindow(self.platform.display, glx.configurations[0], window.handle, null);
                        std.log.debug("glXCreateWindow: {x}", .{window.glx_window});
                    }

                    std.log.debug("glXMakeContextCurrent: {x}", .{glx.context});
                    if (glXMakeContextCurrent(self.platform.display, window.glx_window, window.glx_window, glx.context) == 0)
                        return error.Failure;
                },
                .egl => |egl| undefined,
            }
        }

        pub fn setSwapInterval(self: *Self, window: Platform.Window, interval: u32) void {
            // TODO: MESA_swap_control, SGI_swap_control?
            switch (self.backend) {
                .glx => |glx| {
                    glXSwapIntervalEXT(self.platform.display, window.glx_window, @intCast(c_int, interval));
                },
                .egl => |egl| undefined,
            }
        }

        pub fn swapBuffers(self: *Self, window: Platform.Window) void {
            switch (self.backend) {
                .glx => |glx| {
                    glXSwapBuffers(self.platform.display, window.glx_window);
                },
                .egl => |egl| undefined,
            }
        }
    };
}
