const js = struct {
    extern "zigwin" fn alert(addr: usize, len: usize) void;
};

pub fn alert(str: []const u8) void {
    js.alert(@ptrToInt(str.ptr), str.len);
}
