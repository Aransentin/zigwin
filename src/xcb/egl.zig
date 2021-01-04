const std = @import("std");
const builtin = @import("builtin");
usingnamespace @import("bits.zig");
const zigwin = @import("../zigwin.zig");

var libegl: *c_void = undefined;

pub const EGLDisplay = *opaque {};
const EGLConfig = *opaque {};
pub const EGLSurface = *opaque {};
const EGLContext = *opaque {};

var ext_x11: bool = false;
var ext_xcb: bool = false;

var eglGetPlatformDisplay: fn (platform: c_uint, native_display: *c_void, attrib_list: [*]const usize) callconv(.C) ?EGLDisplay = undefined;
var eglGetProcAddress: fn (procname: [*:0]const u8) callconv(.C) ?*c_void = undefined;
var eglGetError: fn () callconv(.C) i32 = undefined;
var eglInitialize: fn (display: EGLDisplay, major: ?*i32, minor: ?*i32) callconv(.C) c_uint = undefined;
var eglTerminate: fn (display: EGLDisplay) callconv(.C) c_uint = undefined;
var eglChooseConfig: fn (display: EGLDisplay, attrib_list: [*]const i32, configs: [*]EGLConfig, config_size: c_int, num_config: *c_int) callconv(.C) c_uint = undefined;
var eglGetConfigAttrib: fn (display: EGLDisplay, config: EGLConfig, attribute: i32, value: *i32) callconv(.C) c_uint = undefined;
var eglCreateContext: fn (display: EGLDisplay, config: EGLConfig, share_context: ?EGLContext, attrib_list: [*]const i32) callconv(.C) ?EGLContext = undefined;
var eglDestroyContext: fn (display: EGLDisplay, context: EGLContext) callconv(.C) c_uint = undefined;
var eglCreatePlatformWindowSurface: fn (display: EGLDisplay, config: EGLConfig, native_window: *c_void, attrib_list: ?[*]const usize) callconv(.C) ?EGLSurface = undefined;
pub var eglDestroySurface: fn (display: EGLDisplay, surface: EGLSurface) callconv(.C) c_uint = undefined;
var eglMakeCurrent: fn (display: EGLDisplay, draw: ?EGLSurface, read: ?EGLSurface, context: ?EGLContext) callconv(.C) c_uint = undefined;
var eglSwapBuffers: fn (display: EGLDisplay, surface: EGLSurface) callconv(.C) c_uint = undefined;
var eglSwapInterval: fn (display: EGLDisplay, interval: i32) callconv(.C) c_uint = undefined;

fn loadsym(comptime T: type, lib: *c_void, symbol: [*:0]const u8) !T {
    const fpopt = std.c.dlsym(lib, symbol);
    if (fpopt) |fp| {
        return @ptrCast(T, fp);
    } else return error.SymbolNotFound;
}

fn loadsymExt(comptime T: type, symbol: [*:0]const u8) !T {
    const fpopt = eglGetProcAddress(symbol);
    if (fpopt) |fp| {
        return @ptrCast(T, fp);
    } else return error.SymbolNotFound;
}

fn eglDebugCallback(err: c_uint, command: [*:0]const u8, message_type: i32, thread_label: ?*c_void, object_label: ?*c_void, message: [*:0]const u8) callconv(.C) void {
    std.log.warn("{s}: {s}", .{ command, message });
}

pub fn init() !void {
    if (std.c.dlopen("libEGL.so", std.c.RTLD_NOW | std.c.RTLD_LOCAL)) |lib| {
        libegl = lib;
    } else return error.EGLLibraryNotFound;

    var eglBindAPI: fn (api: c_uint) callconv(.C) c_uint = undefined;
    eglBindAPI = try loadsym(@TypeOf(eglBindAPI), libegl, "eglBindAPI");
    if (eglBindAPI(EGL_OPENGL_API) != 1) return error.APIBindFailed;

    var eglQueryString: fn (display: ?EGLDisplay, name: i32) callconv(.C) ?[*:0]u8 = undefined;
    eglQueryString = try loadsym(@TypeOf(eglQueryString), libegl, "eglQueryString");
    const extensions_str = eglQueryString(null, EGL_EXTENSIONS) orelse return error.NoEGLExtensions;
    const extensions = std.mem.span(extensions_str);

    if (std.mem.indexOf(u8, extensions, "EGL_MESA_platform_xcb_TODO") != null) {
        ext_xcb = true;
    }
    if (std.mem.indexOf(u8, extensions, "EGL_EXT_platform_x11") != null) {
        ext_x11 = true;
    }

    eglGetPlatformDisplay = try loadsym(@TypeOf(eglGetPlatformDisplay), libegl, "eglGetPlatformDisplay");
    eglGetError = try loadsym(@TypeOf(eglGetError), libegl, "eglGetError");
    eglGetProcAddress = try loadsym(@TypeOf(eglGetProcAddress), libegl, "eglGetProcAddress");
    eglInitialize = try loadsym(@TypeOf(eglInitialize), libegl, "eglInitialize");
    eglTerminate = try loadsym(@TypeOf(eglTerminate), libegl, "eglTerminate");
    eglChooseConfig = try loadsym(@TypeOf(eglChooseConfig), libegl, "eglChooseConfig");
    eglGetConfigAttrib = try loadsym(@TypeOf(eglGetConfigAttrib), libegl, "eglGetConfigAttrib");
    eglCreateContext = try loadsym(@TypeOf(eglCreateContext), libegl, "eglCreateContext");
    eglDestroyContext = try loadsym(@TypeOf(eglDestroyContext), libegl, "eglDestroyContext");
    eglCreatePlatformWindowSurface = try loadsym(@TypeOf(eglCreatePlatformWindowSurface), libegl, "eglCreatePlatformWindowSurface");
    eglDestroySurface = try loadsym(@TypeOf(eglDestroySurface), libegl, "eglDestroySurface");
    eglMakeCurrent = try loadsym(@TypeOf(eglMakeCurrent), libegl, "eglMakeCurrent");
    eglSwapBuffers = try loadsym(@TypeOf(eglSwapBuffers), libegl, "eglSwapBuffers");
    eglSwapInterval = try loadsym(@TypeOf(eglSwapInterval), libegl, "eglSwapInterval");

    if (builtin.mode == .Debug) {
        if (std.mem.indexOf(u8, extensions, "EGL_KHR_debug") != null) {
            var eglDebugMessageControlKHR: fn (callback: @TypeOf(eglDebugCallback), attrib_list: [*]const usize) callconv(.C) i32 = undefined;
            eglDebugMessageControlKHR = try loadsymExt(@TypeOf(eglDebugMessageControlKHR), "eglDebugMessageControlKHR");
            const attribs = [_][2]usize{
                .{ EGL_DEBUG_MSG_CRITICAL_KHR, 1 },
                .{ EGL_DEBUG_MSG_ERROR_KHR, 1 },
                .{ EGL_DEBUG_MSG_WARN_KHR, 1 },
                .{ EGL_DEBUG_MSG_INFO_KHR, 0 },
                .{ EGL_NONE, EGL_NONE },
            };
            if (eglDebugMessageControlKHR(eglDebugCallback, @ptrCast([*]const usize, &attribs)) != EGL_SUCCESS) {
                return error.FailedSettingDebugCallback;
            }
        }
    }
}

pub fn deinit() void {
    _ = std.c.dlclose(libegl);
}

pub fn initDisplay(comptime Platform: anytype, platform: *Platform) !EGLDisplay {
    const display = blk: {
        if (ext_xcb) {
            unreachable; // TODO when this is released properly as EGL_EXT_platform_xcb
        } else if (Platform.settings.x11_use_xlib and ext_x11) {
            const args = [_][2]usize{
                .{ EGL_PLATFORM_X11_SCREEN_EXT, @intCast(usize, platform.screen_id) },
                .{ EGL_NONE, EGL_NONE },
            };
            break :blk eglGetPlatformDisplay(EGL_PLATFORM_X11_EXT, platform.display, @ptrCast([*]const usize, &args)) orelse return error.NoEGLDisplay;
        } else return error.NoUseableEGLPlatform;
    };

    var egl_major: i32 = 0;
    var egl_minor: i32 = 0;
    if (eglInitialize(display, &egl_major, &egl_minor) != 1) {
        return error.EGLInitializationFailed;
    }

    std.log.scoped(.zigwin).info("Initialized EGL {}.{}", .{ egl_major, egl_minor });
    return display;
}

pub fn deinitDisplay(display: EGLDisplay) void {
    _ = eglTerminate(display);
}

const EGL_SUCCESS = 0x3000;
const EGL_DEBUG_MSG_CRITICAL_KHR = 0x33B9;
const EGL_DEBUG_MSG_ERROR_KHR = 0x33BA;
const EGL_DEBUG_MSG_WARN_KHR = 0x33BB;
const EGL_DEBUG_MSG_INFO_KHR = 0x33BC;

const EGL_PLATFORM_X11_EXT = 0x31D5;
const EGL_PLATFORM_X11_SCREEN_EXT = 0x31D6;
const EGL_OPENGL_API = 0x30A2;

const EGL_NONE = 0x3038;
const EGL_EXTENSIONS = 0x3055;
const EGL_CLIENT_APIS = 0x308D;
const EGL_VENDOR = 0x3053;
const EGL_VERSION = 0x3054;

const EGL_BUFFER_SIZE = 0x3020;
const EGL_ALPHA_SIZE = 0x3021;
const EGL_BLUE_SIZE = 0x3022;
const EGL_GREEN_SIZE = 0x3023;
const EGL_RED_SIZE = 0x3024;
const EGL_DEPTH_SIZE = 0x3025;
const EGL_SAMPLES = 0x3031;
const EGL_RENDERABLE_TYPE = 0x3040;
const EGL_TRANSPARENT_TYPE = 0x3034;
const EGL_TRANSPARENT_RGB = 0x3052;

const EGL_OPENGL_ES_BIT = 0x0001;
const EGL_OPENGL_ES2_BIT = 0x0004;
const EGL_OPENGL_BIT = 0x0008;

const EGL_NATIVE_VISUAL_ID = 0x302E;
const EGL_CONTEXT_CLIENT_VERSION = 0x3098;
const EGL_CONTEXT_MAJOR_VERSION = 0x3098;
const EGL_CONTEXT_MINOR_VERSION = 0x30FB;
const EGL_CONTEXT_OPENGL_PROFILE_MASK = 0x30FD;
const EGL_CONTEXT_OPENGL_DEBUG = 0x31B0;
const EGL_CONTEXT_OPENGL_FORWARD_COMPATIBLE = 0x31B1;
const EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT = 0x00000001;
const EGL_CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT = 0x00000002;

pub fn Context(comptime Platform: anytype) type {
    return struct {
        const Self = @This();
        platform: *Platform,
        config: EGLConfig = undefined,
        visual: VISUALID = undefined,
        visual_depth: u8 = undefined,
        context: EGLContext = undefined,

        pub fn init(platform: *Platform, options: zigwin.OpenGLContextOptions, share: ?*Self) !Self {
            var self = Self{
                .platform = platform,
            };

            const egl_attribs = [_][2]i32{
                .{ EGL_BLUE_SIZE, 1 },
                .{ EGL_BLUE_SIZE, 1 },
                .{ EGL_GREEN_SIZE, 1 },
                .{ EGL_RED_SIZE, 1 },
                .{ EGL_ALPHA_SIZE, options.alpha_bits },
                .{ EGL_DEPTH_SIZE, options.depth_bits },
                .{ EGL_SAMPLES, options.samples },
                .{ EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT },
                .{ EGL_TRANSPARENT_TYPE, if (options.transparent) EGL_TRANSPARENT_RGB else EGL_NONE },
                .{ EGL_NONE, EGL_NONE },
            };

            var num_configs: c_int = 0;
            if (eglChooseConfig(self.platform.egl_display.?, @ptrCast([*]const c_int, &egl_attribs), @ptrCast([*]EGLConfig, &self.config), 1, &num_configs) != 1) return error.EGLChooseConfigFailed;
            if (num_configs == 0) return error.NoEGLConfiguration;
            if (eglGetConfigAttrib(self.platform.egl_display.?, self.config, EGL_NATIVE_VISUAL_ID, @ptrCast(*i32, &self.visual)) != 1) return error.NoEGLVisualReturned;

            const ctx_attribs = [_][2]i32{
                .{ EGL_CONTEXT_MAJOR_VERSION, options.major },
                .{ EGL_CONTEXT_MINOR_VERSION, options.minor },
                .{ EGL_CONTEXT_OPENGL_PROFILE_MASK, if (options.core) EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT else EGL_CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT },
                .{ EGL_CONTEXT_OPENGL_DEBUG, if (options.debug) 1 else 0 },
                .{ EGL_CONTEXT_OPENGL_FORWARD_COMPATIBLE, if (options.forward_compatible) 1 else 0 },
                .{ EGL_NONE, EGL_NONE },
            };
            const ctx = eglCreateContext(self.platform.egl_display.?, self.config, if (share != null) share.?.context else null, @ptrCast([*]const c_int, &ctx_attribs));
            if (ctx == null) return error.EGLCreateContextFailed;
            self.context = ctx.?;

            // Find the actual visual depth
            self.visual_depth = blk: {
                const setup = xcbGetSetup(platform.connection);
                var screen_iter = xcbSetupRootsIterator(setup);
                var i: usize = 0;
                while (true) : (i += 1) {
                    if (i == platform.screen_id) break;
                    xcbScreenNext(&screen_iter);
                }
                const screen = screen_iter.data;
                var depth_iter = xcbScreenAllowedDepthsIterator(screen);
                while (depth_iter.rem != 0) {
                    const depth = depth_iter.data;
                    var visuals_iter = xcbDepthVisualsIterator(depth_iter.data);
                    while (visuals_iter.rem != 0) {
                        const visual = visuals_iter.data;
                        if (visual.visual_id == self.visual) {
                            break :blk depth.depth;
                        }
                        xcbVisualtypeNext(&visuals_iter);
                    }
                    xcbDepthNext(&depth_iter);
                }
                unreachable;
            };

            return self;
        }

        pub fn deinit(self: *Self) void {
            _ = eglDestroyContext(self.platform.egl_display.?, self.context);
        }

        pub fn makeCurrent(self: *Self, window: *Platform.Window) !void {
            if (window.egl_surface == null) {
                const attribs = [_][2]usize{
                    .{ EGL_NONE, EGL_NONE },
                };
                const surface = eglCreatePlatformWindowSurface(self.platform.egl_display.?, self.config, &window.handle, @ptrCast([*]const usize, &attribs));
                if (surface == null) {
                    return error.FailedCreatingEGLSurface;
                } else {
                    window.egl_surface = surface;
                }
            }

            if (eglMakeCurrent(self.platform.egl_display.?, window.egl_surface.?, window.egl_surface.?, self.context) != 1) {
                return error.FailedSettingContext;
            }
        }

        pub fn setSwapInterval(self: *Self, interval: u32) void {
            _ = eglSwapInterval(self.platform.egl_display.?, @intCast(i32, interval));
        }

        pub fn swapBuffers(self: *Self, window: Platform.Window) void {
            if (eglSwapBuffers(self.platform.egl_display.?, window.egl_surface.?) != 1) {
                std.log.debug("swapBuffers failed", .{});
            }
        }
    };
}
