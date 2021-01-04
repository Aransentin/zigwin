const std = @import("std");
const builtin = @import("builtin");

const wayland = @import("wayland/wayland.zig");
const x11 = @import("x11/x11.zig");
const xcb = @import("xcb/xcb.zig");
const windows = @import("windows/windows.zig");
const browser = @import("browser/browser.zig");

/// Global compile-time platform settings
pub const PlatformSettings = struct {
    /// If you need to track data about specific monitors, set this to true. Usually not needed for
    /// always-windowed applications or programs that don't need explicit control on what monitor to
    /// fullscreen themselves on.
    monitors: bool = false,

    /// Specify what type(s) of rendering you would like to be able to perform.
    render_software: bool = true,
    render_opengl: bool = false,
    render_vulkan: bool = false,
    /// If the initial OpenGL context creation fails, don't fail the entire platform so that fallback
    /// rendering can be done instead. Requires the caller to check platform.supportsOpenGL() afterwards.
    // TODO
    render_opengl_soft: bool = false,

    /// When building for Linux, add support for Wayland
    wayland: bool = true,

    /// When building for Linux, add support for X11
    x11: bool = true,

    /// Hardware rendering on X11 requires calling an X11 C library, either XCB or Xlib. Xlib is an old, slow wrapper layer
    /// around XCB that's worse in all respects but often necessary for OpenGL context creation and in a Vulkan edge case: there
    /// is one Xlib extension (VK_EXT_acquire_xlib_display) that does not have an XCB analogue.
    x11_use_xlib: bool = false,

    /// If you set 'hdr' to true, the pixel buffer(s) you get for software rendering is in the native window/monitor
    /// colour depth, which can have more (or fewer, technically) than 8 bits per colour.
    /// If false, the library will always give you an 8-bit buffer and automatically convert it to
    /// the native depth for you if needed.
    hdr: bool = false,
};

/// The window mode. All options degrade downwards towards the following option if not supported by the platform.
pub const WindowMode = enum {
    /// The window is an icon on the system tray.
    Systray,

    /// The window is minimized to the task bar.
    Minimized,

    /// A normal desktop window.
    Windowed,

    /// A normal desktop window, resized so that it covers the entire screen. Compared to proper fullscreen
    /// this does not bypass the compositor, which usually adds one frame of latency and degrades performance slightly.
    /// The upside is that switching desktops or alt-tabbing from this application to another is much faster.
    WindowedFullscreen,

    /// A normal fullscreen window.
    Fullscreen,
};

/// Options for windows
pub const WindowOptions = struct {
    /// The title of the window. Ignored if the platform does not support it. If specifying a title is not optional
    /// for the current platform, a null title will be interpreted as an empty string.
    title: ?[]const u8 = null,

    width: u16 = 1024,
    height: u16 = 600,
    visible: bool = true,
    mode: WindowMode = .Windowed,

    /// Whether the user is allowed to resize the window or not. Note that this is more of a suggestion,
    /// and the window manager could resize us anyway if it so chooses.
    resizeable: bool = true,

    /// Set this to "true" you want the default system border and title bar with the name, buttons, etc. when windowed.
    /// Set this to "false" if you're a time traveller from 1999 developing your latest winamp skin or something.
    decorations: bool = true,

    /// Set 'transparent' to true if you'd like to get pixels with an alpha component, so that parts of your window
    /// can be made transparent. Note that this will only work if the platform has a compositor running.
    transparent: bool = false,

    /// This means you will get an event every time vblank happens after you've submitted a pixel update.
    track_vblank: bool = false,

    /// This means that the event callback will notify you if any of your window is "damaged", i.e..
    /// needs to be re-rendered due to (for example) another window having covered part of it.
    /// Not needed if you're constantly re-rendering the entire window anyway.
    track_damage: bool = false,

    /// This means that mouse motion and click events will be tracked.
    track_mouse: bool = false,

    /// This means that keyboard events will be tracked.
    track_keyboard: bool = false,

    /// Setting this to a previously created OpenGLContext will ensure
    /// that the window is compatible with it.
    opengl_context_compatible: ?*c_void = null,
};

/// Options for OpenGL context creation
pub const OpenGLContextOptions = struct {
    major: u8,
    minor: u8,
    core: bool = true,
    forward_compatible: bool = true,
    debug: bool = false,

    alpha_bits: u8 = 0,
    depth_bits: u8 = 24,
    transparent: bool = false,
    samples: u8 = 0,
};

pub fn Platform(comptime settings: PlatformSettings) type {
    if (builtin.os.tag == .windows) return windows.Platform(settings);
    if (builtin.arch.isWasm()) return browser.Platform(settings);
    if (builtin.os.tag == .linux) {
        const x11plat = if (!settings.render_opengl and !settings.render_vulkan) x11 else xcb;
        if (!settings.x11 and settings.wayland) return wayland.Platform(settings);
        if (settings.x11 and !settings.wayland) return x11plat.Platform(settings);
        if (settings.x11 and settings.wayland) @compileError("Linux multi-platform not yet implemented");
        @compileError("No Linux platform selected");
    }
    @compileError("Unsupported platform");
}
