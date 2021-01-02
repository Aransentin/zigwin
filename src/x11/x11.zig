const std = @import("std");
const builtin = @import("builtin");
const zigwin = @import("../zigwin.zig");
usingnamespace @import("bits.zig");

const ReplyBuffer = @import("replybuffer.zig").ReplyBuffer;
const DisplayInfo = @import("display_info.zig").DisplayInfo;
const AuthCookie = @import("auth.zig").AuthCookie;
const setup = @import("setup.zig");

pub fn Platform(comptime _settings: anytype) type {
    return struct {
        pub const settings = _settings;
        const Self = @This();
        socket: std.os.fd_t = undefined,

        replybuf: ReplyBuffer = .{},

        xid_next: u32 = undefined,
        root: WINDOW = undefined,
        root_depth: u8 = undefined,
        root_color_bits: u8 = undefined,
        alpha_compat_visual: u32 = undefined,

        ext_op_xfixes: u8 = 0,
        ext_op_mitshm: u8 = 0,
        ext_op_randr: u8 = 0,
        ext_op_present: u8 = 0,
        ext_ev_present: u8 = 0,
        ext_op_xinput: u8 = 0,

        atom_motif_wm_hints: u32 = 0,

        pub fn init() !Self {
            var self = Self{};

            // Prepare all the info we need to connect before actually attempting to do so
            const display_info = try DisplayInfo.parse();
            const auth_cookie = AuthCookie.parse(display_info) catch null;
            self.socket = try connectToDisplay(display_info.display);
            errdefer std.os.close(self.socket);

            // The setup does the handshake and initializes all the extensions and atoms we need
            try setup.do(&self, display_info, auth_cookie);

            std.log.scoped(.zigwin).info("Platform Initialized: X11", .{});
            return self;
        }

        pub fn deinit(self: *Self) void {
            std.os.close(self.socket);
        }
    };
}

fn connectToDisplay(display: u8) !std.os.fd_t {
    const fd = try std.os.socket(std.os.AF_UNIX, std.os.SOCK_STREAM | std.os.SOCK_CLOEXEC, 0);
    errdefer std.os.close(fd);
    var addr = std.os.sockaddr_un{ .path = [_]u8{0} ** 108 };
    std.mem.copy(u8, addr.path[0..], "\x00/tmp/.X11-unix/X");
    _ = std.fmt.formatIntBuf(addr.path["\x00/tmp/.X11-unix/X".len..], display, 10, false, .{});
    const addrlen = 1 + std.mem.lenZ(@ptrCast([*:0]u8, addr.path[1..]));
    try std.os.connect(fd, @ptrCast(*const std.os.sockaddr, &addr), @sizeOf(std.os.sockaddr_un) - @intCast(u32, addr.path.len - addrlen));
    return fd;
}
