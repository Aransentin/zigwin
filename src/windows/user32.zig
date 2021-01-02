const std = @import("std");
usingnamespace @import("bits.zig");
pub const kernel32 = @import("kernel32.zig");

const unexpectedError = std.os.windows.unexpectedError;
const GetLastError = kernel32.GetLastError;
const SetLastError = kernel32.SetLastError;

pub const HWND = *opaque {};
pub const HDC = *opaque {};
pub const HBRUSH = *opaque {};
pub const HCURSOR = *opaque {};
pub const HICON = *opaque {};

pub const WPARAM = usize;
pub const LPARAM = ?*c_void;
pub const LRESULT = ?*c_void;
pub const WNDPROC = fn (HWND, u32, WPARAM, LPARAM) callconv(WINAPI) LRESULT;

pub const CS_VREDRAW = 0x0001;
pub const CS_HREDRAW = 0x0002;
pub const CS_DBLCLKS = 0x0008;
pub const CS_OWNDC = 0x0020;
pub const CS_CLASSDC = 0x0040;
pub const CS_PARENTDC = 0x0080;
pub const CS_NOCLOSE = 0x0200;
pub const CS_SAVEBITS = 0x0800;
pub const CS_BYTEALIGNCLIENT = 0x1000;
pub const CS_BYTEALIGNWINDOW = 0x2000;
pub const CS_GLOBALCLASS = 0x4000;

pub const WNDCLASSEXA = extern struct {
    cbSize: u32 = @sizeOf(WNDCLASSEXA),
    style: u32,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32 = 0,
    cbWndExtra: i32 = 0,
    hInstance: HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH,
    lpszMenuName: ?[*:0]const u8,
    lpszClassName: [*:0]const u8,
    hIconSm: ?HICON,
};

pub extern "user32" fn RegisterClassExA(*const WNDCLASSEXA) callconv(WINAPI) ATOM;
pub fn registerClassExA(window_class: *const WNDCLASSEXA) !ATOM {
    const atom = RegisterClassExA(window_class);
    if (atom != 0) return atom;
    switch (GetLastError()) {
        .CLASS_ALREADY_EXISTS => return error.AlreadyExists,
        .INVALID_PARAMETER => unreachable,
        else => |err| return unexpectedError(err),
    }
}

pub extern "user32" fn UnregisterClassA(lpClassName: [*:0]const u8, hInstance: HINSTANCE) callconv(WINAPI) BOOL;
pub fn unregisterClassA(lpClassName: [*:0]const u8, hInstance: HINSTANCE) !void {
    if (UnregisterClassA(lpClassName, hInstance) == 0) {
        switch (GetLastError()) {
            .CLASS_DOES_NOT_EXIST => return error.ClassDoesNotExist,
            else => |err| return unexpectedError(err),
        }
    }
}
