const std = @import("std");
const builtin = @import("builtin");
const zigwin = @import("../zigwin.zig");
const Allocator = std.mem.Allocator;

pub const kernel32 = @import("kernel32.zig");
pub const user32 = @import("user32.zig");
usingnamespace @import("bits.zig");

pub fn Platform(comptime _settings: anytype) type {
    return struct {
        const settings = _settings;
        const Self = @This();
        instance: HINSTANCE = undefined,

        pub fn init() !Self {
            var self = Self{};

            const module_handle = kernel32.GetModuleHandleA(null) orelse unreachable;
            self.instance = @ptrCast(HINSTANCE, module_handle);

            const window_class_info = user32.WNDCLASSEXA{
                .style = user32.CS_OWNDC | user32.CS_HREDRAW | user32.CS_VREDRAW,
                .lpfnWndProc = undefined,
                .cbClsExtra = 0,
                .cbWndExtra = @sizeOf(usize),
                .hInstance = self.instance,
                .hIcon = null,
                .hCursor = null,
                .hbrBackground = null,
                .lpszMenuName = null,
                .lpszClassName = "zigwin",
                .hIconSm = null,
            };
            _ = try user32.registerClassExA(&window_class_info);

            std.log.scoped(.zigwin).info("Platform Initialized: Windows", .{});
            return self;
        }

        pub fn deinit(self: *Self) void {
            _ = user32.unregisterClassA("zigwin", self.instance) catch unreachable;
        }
    };
}
