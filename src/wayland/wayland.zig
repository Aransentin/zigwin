const std = @import("std");
const builtin = @import("builtin");
const zigwin = @import("../zigwin.zig");

pub fn Platform(comptime _settings: anytype) type {
    return struct {
        const settings = _settings;
        const Self = @This();
        socket: std.os.fd_t = undefined,

        pub fn init() !Self {
            var self = Self{};

            self.socket = try connectToServer();
            errdefer std.os.close(self.socket);

            std.log.scoped(.zigwin).info("Platform Initialized: Wayland", .{});
            return self;
        }

        pub fn deinit(self: *Self) void {
            std.os.close(self.socket);
        }
    };
}

fn connectToServer() !std.os.fd_t {
    if (std.os.getenvZ("WAYLAND_SOCKET")) |WAYLAND_SOCKET| {
        return try std.fmt.parseInt(i32, WAYLAND_SOCKET, 10);
    }

    const XDG_RUNTIME_DIR = std.os.getenvZ("XDG_RUNTIME_DIR") orelse "";
    const WAYLAND_DISPLAY = std.os.getenvZ("WAYLAND_DISPLAY") orelse "wayland-0";
    var membuf: [256]u8 = undefined;
    if (XDG_RUNTIME_DIR.len + WAYLAND_DISPLAY.len + 1 > membuf.len) return error.PathTooLong;
    std.mem.copy(u8, membuf[0..], XDG_RUNTIME_DIR);
    membuf[XDG_RUNTIME_DIR.len] = '/';
    std.mem.copy(u8, membuf[XDG_RUNTIME_DIR.len + 1 ..], WAYLAND_DISPLAY);
    const path = membuf[0 .. XDG_RUNTIME_DIR.len + WAYLAND_DISPLAY.len + 1];

    const fd = try std.os.socket(std.os.AF_UNIX, std.os.SOCK_STREAM | std.os.SOCK_CLOEXEC, 0);
    errdefer std.os.close(fd);
    var addr = std.os.sockaddr_un{ .path = [_]u8{0} ** 108 };
    std.mem.copy(u8, addr.path[0..], path);
    try std.os.connect(fd, @ptrCast(*const std.os.sockaddr, &addr), @sizeOf(std.os.sockaddr_un) - @intCast(u32, addr.path.len - path.len));
    return fd;
}
