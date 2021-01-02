const std = @import("std");
const builtin = @import("builtin");
const zigwin = @import("../zigwin.zig");
const DisplayInfo = @import("display_info.zig").DisplayInfo;
const win32 = @import("../windows/win32.zig");

pub const AuthCookie = struct {
    data: [16]u8,

    pub fn parse(display_info: DisplayInfo) !AuthCookie {
        const xauthority_file = blk: {
            if (std.os.getenv("XAUTHORITY")) |path| break :blk try std.fs.openFileAbsolute(path, .{ .read = true, .write = false });
            const home = std.os.getenv("HOME") orelse return error.HomeDirectoryNotFound;

            // Yes, this is significantly uglier than just using mem.joinZ or the like, but it saves more than 1KiB of binary size
            var membuf: [256]u8 = undefined;
            if (home.len + "/.Xauthority".len + 1 > membuf.len) return error.PathTooLong;
            std.mem.copy(u8, membuf[0..], home);
            std.mem.copy(u8, membuf[home.len + 1 ..], "/.Xauthority");
            membuf[home.len + "/.Xauthority".len] = 0;
            const path = membuf[0 .. home.len + "/.Xauthority".len];
            break :blk try std.fs.openFileAbsoluteZ(@ptrCast([*:0]const u8, path.ptr), .{ .read = true, .write = false });
        };
        defer xauthority_file.close();

        var rbuf = std.io.bufferedReader(xauthority_file.reader());
        var reader = rbuf.reader();

        const uts = std.os.uname();
        const hostname = std.mem.spanZ(std.meta.assumeSentinel(&uts.nodename, 0));

        var best_score: u8 = 0;
        var best_token: [16]u8 = undefined;
        var best_cookie_n: usize = 0;

        while (true) {
            const family = reader.readIntBig(u16) catch break;
            const addr_len = reader.readIntBig(u16) catch break;
            if (addr_len > 255) break;

            var addrbuf: [256]u8 = undefined;
            _ = reader.readAll(addrbuf[0..addr_len]) catch break;
            const addr = addrbuf[0..addr_len];

            const num_len = reader.readIntBig(u16) catch break;
            if (num_len > 8) break;

            var numbuf: [8]u8 = undefined;
            _ = reader.readAll(numbuf[0..num_len]) catch break;

            const display = std.fmt.parseUnsigned(u8, numbuf[0..num_len], 10) catch 0;

            const name_len = reader.readIntBig(u16) catch break;
            if (name_len != 18) {
                reader.skipBytes(name_len, .{ .buf_size = 64 }) catch break;
                const data_len = reader.readIntBig(u16) catch break;
                reader.skipBytes(data_len, .{ .buf_size = 64 }) catch break;
                continue;
            }

            var nbuf: [18]u8 = undefined;
            _ = reader.readAll(nbuf[0..]) catch break;
            if (!std.mem.eql(u8, nbuf[0..], "MIT-MAGIC-COOKIE-1")) {
                const data_len = reader.readIntBig(u16) catch break;
                reader.skipBytes(data_len, .{ .buf_size = 64 }) catch break;
                continue;
            }

            const data_len = reader.readIntBig(u16) catch break;
            if (data_len != 16) {
                reader.skipBytes(data_len, .{ .buf_size = 64 }) catch break;
                continue;
            }

            var xauth_data: [16]u8 = undefined;
            _ = reader.readAll(xauth_data[0..]) catch break;

            var score: u8 = 1;
            if (std.mem.eql(u8, addr, hostname)) score += 1;
            if (family == 0xff) score += 1;
            if (display == display_info.display) score += 1;
            if (score > best_score) {
                best_score = score;
                best_token = xauth_data;
            }
        }

        if (best_score == 0) return error.NoXAuthorityTokenFound;
        return AuthCookie{ .data = best_token };
    }
};
