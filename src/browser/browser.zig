const std = @import("std");
const builtin = @import("builtin");
const zigwin = @import("../zigwin.zig");
const imports = @import("imports.zig");

pub fn Platform(comptime _settings: anytype) type {
    return struct {
        const settings = _settings;
        const Self = @This();

        pub fn init() !Self {
            var self = Self{};

            imports.alert("Zigwin test");
            return self;
        }

        pub fn deinit(self: *Self) void {
            // Do
        }
    };
}
