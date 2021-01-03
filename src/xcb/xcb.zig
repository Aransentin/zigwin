const std = @import("std");
const builtin = @import("builtin");
const zigwin = @import("../zigwin.zig");
const egl = @import("egl.zig");
usingnamespace @import("bits.zig");
const Allocator = std.mem.Allocator;

var refcount: u8 = 0;

pub fn Platform(comptime _settings: anytype) type {
    return struct {
        pub const settings = _settings;
        const Self = @This();
        display: if (settings.x11_use_xlib) *Display else void = undefined,
        connection: *Connection = undefined,

        screen_id: c_int = 0,
        root: WINDOW = undefined,
        root_depth: u8 = undefined,
        root_color_bits: u8 = undefined,
        alpha_compat_visual: VISUALID = 0,

        window: ?*Window = null,
        egl_display: if (settings.render_opengl) ?egl.EGLDisplay else void = undefined,

        pub fn init() !Self {
            var self = Self{};

            if (refcount == 0) {
                try xcbInit(settings.x11_use_xlib);
                errdefer xcbDeinit(settings.x11_use_xlib);
                if (settings.render_opengl) {
                    try egl.init();
                }
            }
            refcount += 1;

            errdefer {
                if (refcount == 1) {
                    xcbDeinit(settings.x11_use_xlib);
                    if (settings.render_opengl) {
                        egl.deinit();
                    }
                }
                refcount -= 1;
            }

            if (settings.x11_use_xlib) {
                self.display = try xOpenDisplay(null);
                self.connection = xGetXCBConnection(self.display);
                self.screen_id = xDefaultScreen(self.display);
                xSetEventQueueOwner(self.display, true);
            } else {
                self.connection = try xcbConnect(null, &self.screen_id);
            }
            errdefer {
                if (settings.x11_use_xlib) {
                    xCloseDisplay(self.display);
                } else {
                    xcbDisconnect(self.connection);
                }
            }

            // Get the correct screen
            const setup = xcbGetSetup(self.connection);
            var screen_iter = xcbSetupRootsIterator(setup);
            var i: usize = 0;
            while (true) : (i += 1) {
                if (i == self.screen_id) break;
                if (screen_iter.rem == 0) return error.InvalidScreen;
                xcbScreenNext(&screen_iter);
            }
            const screen = screen_iter.data;
            self.root = screen.root;
            self.root_depth = screen.root_depth;

            // Find the visual info we need
            var depth_iter = xcbScreenAllowedDepthsIterator(screen);
            while (depth_iter.rem != 0) {
                const depth = depth_iter.data;
                var visuals_iter = xcbDepthVisualsIterator(depth_iter.data);
                while (visuals_iter.rem != 0) {
                    const visual = visuals_iter.data;
                    if (visual.visual_id == screen.root_visual) {
                        self.root_color_bits = visual.bits_per_rgb_value;
                    }
                    if (self.alpha_compat_visual == 0 and visual.class == 4 and depth.depth == 32 and visual.bits_per_rgb_value == 8) {
                        self.alpha_compat_visual = visual.visual_id;
                    }
                    xcbVisualtypeNext(&visuals_iter);
                }
                xcbDepthNext(&depth_iter);
            }

            // todo: atoms

            if (settings.render_opengl) {
                self.egl_display = try egl.initDisplay(Self, &self);
            }

            if (settings.x11_use_xlib) {
                std.log.scoped(.zigwin).info("Platform Initialized: Xlib-XCB", .{});
            } else {
                std.log.scoped(.zigwin).info("Platform Initialized: XCB", .{});
            }
            return self;
        }

        pub fn deinit(self: *Self) void {
            if (settings.render_opengl) {
                egl.deinitDisplay(self.egl_display.?);
            }

            if (settings.x11_use_xlib) {
                xCloseDisplay(self.display);
            } else {
                xcbDisconnect(self.connection);
            }

            if (refcount == 1) {
                if (settings.render_opengl) {
                    egl.deinit();
                }
                xcbDeinit(settings.x11_use_xlib);
            }
            refcount -= 1;
        }

        pub fn waitForEvent(self: *Self) !Event {
            try xcbFlush(self.connection);
            while (true) {
                const event = try xcbWaitForEvent(self.connection);
                defer std.c.free(event);
                if (try self.handleXcbEvent(event)) |ev| return ev;
            }
        }

        pub fn pollForEvent(self: *Self) !?Event {
            try xcbFlush(self.connection);
            while (true) {
                const event = (try xcbPollForEvent(self.connection)) orelse return null;
                defer std.c.free(event);

                std.log.debug("{}", .{event});

                if (try self.handleXcbEvent(event)) |ev| return ev;
            }
        }

        fn handleXcbEvent(self: *Self, event: *GenericEvent) !?Event {
            switch (event.response_type & ~@as(u8, 0x80)) {
                XCB_CONFIGURE_NOTIFY => {
                    const configure_notify_event = @ptrCast(*ConfigureNotifyEvent, event);
                    var window = self.window;
                    while (window != null and window.?.handle != configure_notify_event.window) window = window.?.next;
                    if (window) |win| {
                        win.width = configure_notify_event.width;
                        win.height = configure_notify_event.height;
                        return Event{ .window_resized = win };
                    }
                },
                XCB_EXPOSE => {
                    const expose_event = @ptrCast(*ExposeEvent, event);
                    // std.log.debug("{}", .{expose_event});
                },
                XCB_DESTROY_NOTIFY => {
                    const destroy_notify_event = @ptrCast(*DestroyNotifyEvent, event);
                    var window = self.window;
                    while (window != null and window.?.handle != destroy_notify_event.window) window = window.?.next;
                    if (window) |win| {
                        win.handle = 0;
                        return Event{ .window_destroyed = win };
                    }
                },
                else => {},
            }
            return null;
        }

        pub fn freeEvent(self: *Self, event: Event) void {
            switch (event) {
                else => {},
            }
        }

        pub fn createWindow(self: *Self, window: *Window, options: zigwin.WindowOptions) !void {
            var wptr = &self.window;
            while (wptr.* != null) wptr = &wptr.*.?.next;
            wptr.* = window;
            window.* = .{
                .next = null,
                .platform = self,
            };

            window.init(options);
        }

        fn _createOpenGLContext(self: *Self, options: zigwin.OpenGLContextOptions, share: ?*egl.Context(Self)) !egl.Context(Self) {
            var context = try egl.Context(Self).init(self, options, share);
            return context;
        }
        pub const createOpenGLContext = if (settings.render_opengl) _createOpenGLContext else void;

        pub const Window = @import("window.zig").Window(Self);

        pub const EventType = enum {
            window_resized,
            window_destroyed,
            window_damaged,
            window_vblank,
            platform_terminated,
        };

        pub const Event = union(EventType) {
            window_resized: *Window,
            window_destroyed: *Window,
            window_damaged: struct { window: *Window, x: u16, y: u16, w: u16, h: u16 },
            window_vblank: *Window,
            platform_terminated: void,
        };
    };
}
