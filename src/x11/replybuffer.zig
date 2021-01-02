const std = @import("std");
const builtin = @import("builtin");

// A tiny circular buffer to store queries we are interested in receiving the replies from.
// Also tracks the current sequence id, so ignoreEvent must be called for every request.
pub const ReplyBuffer = struct {
    const ReplyEvent = struct {
        seq: u32,
        id: u32,
    };

    // The size of this buffer sets a hard cap on the amount of in-flight events we can
    // keep track of at the same time. Note that this does not include events we don't
    // care about the response from, or we don't need to know exactly what triggered the
    // event to be able to handle properly.
    mem: [8]ReplyEvent = undefined,
    tail: u8 = 0,
    head: u8 = 0,
    seq_next: u32 = 1,

    pub fn len(self: *ReplyBuffer) usize {
        var hp: usize = self.head;
        if (self.head < self.tail)
            hp += self.mem.len;
        return hp - self.tail;
    }

    pub fn push(self: *ReplyBuffer, id: u32) !void {
        if (self.len() == self.mem.len - 1) return error.OutOfMemory;
        self.mem[self.head] = .{ .id = id, .seq = self.seq_next };
        self.seq_next += 1;
        self.head = @intCast(u8, (self.head + 1) % self.mem.len);
    }

    pub fn ignoreEvent(self: *ReplyBuffer) void {
        self.seq_next += 1;
    }

    pub fn get(self: *ReplyBuffer, seq: u32) ?u32 {
        while (self.len() > 0) {
            const tailp = self.tail;
            const ev = self.mem[tailp];
            if (ev.seq < seq) {
                unreachable;
            } else if (ev.seq == seq) {
                self.tail = @intCast(u8, (self.tail + 1) % self.mem.len);
                return ev.id;
            } else {
                return null;
            }
        }
        return null;
    }
};
