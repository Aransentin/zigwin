const std = @import("std");
const builtin = @import("builtin");
usingnamespace @import("bits.zig");
const zigwin = @import("../zigwin.zig");
const opengl = @import("opengl.zig");

pub fn Window(comptime Platform: anytype) type {
    return struct {
        const Self = @This();
        next: ?*Self,
        platform: *Platform,

        handle: WINDOW = 0,
        colormap: COLORMAP = 0,

        width: u16 = undefined,
        height: u16 = undefined,

        glx_window: if (Platform.settings.render_opengl) opengl.GLXWindow else void = undefined,

        pub fn init(self: *Self, options: zigwin.WindowOptions) void {
            self.handle = xcbGenerateId(self.platform.connection);
            self.width = options.width;
            self.height = options.height;

            if (Platform.settings.render_opengl) {
                self.glx_window = 0;
            }

            // Ugly cast to get rid of the ?*c_void that the option needs
            const gl_context = if (Platform.settings.render_opengl and options.opengl_context_compatible != null) @ptrCast(*opengl.Context(Platform), @alignCast(8, options.opengl_context_compatible)) else null;

            // Decide what visual and depth to use
            var visual: VISUALID = 0;
            var depth: u8 = self.platform.root_depth;
            if (gl_context) |ctx| {
                visual = ctx.visual;
                depth = ctx.visual_depth;
            } else if (Platform.settings.hdr == false or options.transparent == true) {
                visual = self.platform.alpha_compat_visual;
                depth = 32;
            }

            // A colormap is needed to make non-native VISUALs
            if (visual != 0) {
                self.colormap = xcbGenerateId(self.platform.connection);
                _ = xcbCreateColormap(self.platform.connection, 0, self.colormap, self.platform.root, visual);
            }

            // Create the window itself
            var values_n: usize = 0;
            var value_mask: u32 = 0;
            var value_list: [8]u32 = undefined;

            value_list[values_n] = 0;
            value_mask |= XCB_CW_BACK_PIXEL;
            values_n += 1;

            value_list[values_n] = 0;
            value_mask |= XCB_CW_BORDER_PIXEL;
            values_n += 1;

            value_list[values_n] = XCB_EVENT_MASK_STRUCTURE_NOTIFY;
            value_list[values_n] |= if (options.track_damage == true) @as(u32, XCB_EVENT_MASK_EXPOSURE) else 0;
            value_mask |= XCB_CW_EVENT_MASK;
            values_n += 1;

            if (self.colormap != 0) {
                value_list[values_n] = self.colormap;
                value_mask |= XCB_CW_COLORMAP;
                values_n += 1;
            }
            _ = xcbCreateWindow(self.platform.connection, depth, self.handle, self.platform.root, 0, 0, self.width, self.height, 0, XCB_WINDOW_CLASS_INPUT_OUTPUT, visual, value_mask, &value_list);

            // Keyboard, mouse... -> XInput

            // todo: set mode
            if (options.title) |title| self.setTitle(title) catch unreachable;
            if (options.decorations == false) self.setDecorations(false) catch unreachable;
            if (options.resizeable == false) self.setResizeable(false) catch unreachable;
            if (options.visible == true) self.setVisibility(true) catch unreachable;
        }

        pub fn deinit(self: *Self) void {
            var wptr = &self.platform.window;
            while (wptr.* != self) wptr = &wptr.*.?.next;
            wptr.* = self.next;

            if (Platform.settings.render_opengl) {
                if (self.glx_window != 0) {
                    std.log.debug("glXDestroyWindow: {x}", .{self.glx_window});
                    opengl.glXDestroyWindow(self.platform.display, self.glx_window);
                }
            }

            if (self.handle != 0) {
                _ = xcbDestroyWindow(self.platform.connection, self.handle);
            }

            if (self.colormap != 0) {
                _ = xcbFreeColormap(self.platform.connection, self.colormap);
            }
        }

        pub fn setTitle(self: *Self, title: ?[]const u8) !void {
            if (title) |tt| {
                _ = xcbChangeProperty(self.platform.connection, XCB_PROP_MODE_REPLACE, self.handle, XCB_ATOM_WM_NAME, XCB_ATOM_STRING, 8, @intCast(u32, tt.len), tt.ptr);
            }
        }

        pub fn setDecorations(self: *Self, state: bool) !void {
            // todo
        }

        pub fn setResizeable(self: *Self, state: bool) !void {
            // todo
        }

        pub fn setVisibility(self: *Self, state: bool) !void {
            if (state) {
                _ = xcbMapWindow(self.platform.connection, self.handle);
            } else {
                _ = xcbUnapWindow(self.platform.connection, self.handle);
            }
        }
    };
}
