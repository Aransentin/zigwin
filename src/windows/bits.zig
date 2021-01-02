const std = @import("std");
const builtin = @import("builtin");
pub usingnamespace struct {
    pub const Win32Error = std.os.windows.Win32Error;
};

pub const BOOL = c_int;
pub const WINAPI: builtin.CallingConvention = if (builtin.arch == .i386) .Stdcall else .C;
pub const HINSTANCE = *opaque {};
pub const HMODULE = *opaque {};
pub const ATOM = u16;
