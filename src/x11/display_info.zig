const std = @import("std");
const builtin = @import("builtin");

pub const DisplayInfo = struct {
    display: u6 = 0,
    screen: u8 = 0,

    pub fn parse() !DisplayInfo {
        const DISPLAY = std.os.getenvZ("DISPLAY") orelse return DisplayInfo{ .display = 0, .screen = 0 };

        const colon = std.mem.indexOfScalar(u8, DISPLAY, ':') orelse return error.MalformedDisplay;
        const dot = std.mem.indexOfScalar(u8, DISPLAY[colon..], '.');
        if (dot != null and dot.? == 1) return error.MalformedDisplay;
        const display = if (dot != null) try std.fmt.parseUnsigned(u6, DISPLAY[colon + 1 .. colon + dot.?], 10) else try std.fmt.parseUnsigned(u6, DISPLAY[colon + 1 ..], 10);
        const screen = if (dot != null) try std.fmt.parseUnsigned(u8, DISPLAY[colon + dot.? + 1 ..], 10) else 0;
        return DisplayInfo{ .display = display, .screen = screen };
    }
};
