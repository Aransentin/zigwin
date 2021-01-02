usingnamespace @import("bits.zig");

pub extern "kernel32" fn GetLastError() callconv(WINAPI) Win32Error;
pub extern "kernel32" fn SetLastError(dwErrCode: Win32Error) callconv(WINAPI) void;
pub extern "kernel32" fn GetModuleHandleA(lpModuleName: ?[*:0]const u8) callconv(WINAPI) ?HMODULE;
