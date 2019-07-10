const assert = @import("std").debug.assert;
const math = @import("std").math;
const testing = @import("std").testing;

pub fn roundUpAlign(p: usize, a: usize) usize {
    assert(math.isPowerOfTwo(a));

    return (p + (a - 1)) & ~(a - 1);
}

test "roundUpAlign rounds up numbers" {
    testing.expectEqual(usize(0), roundUpAlign(0, 1));
    testing.expectEqual(usize(1), roundUpAlign(1, 1));
    testing.expectEqual(usize(2), roundUpAlign(2, 1));

    testing.expectEqual(usize(0), roundUpAlign(0, 4));
    testing.expectEqual(usize(4), roundUpAlign(1, 4));
    testing.expectEqual(usize(4), roundUpAlign(2, 4));
    testing.expectEqual(usize(4), roundUpAlign(3, 4));
    testing.expectEqual(usize(4), roundUpAlign(4, 4));
    testing.expectEqual(usize(8), roundUpAlign(5, 4));
}

// To be used by tests
pub const Xorshift32 = struct {
    state: u32,

    const Self = @This();

    pub fn init(seed: u32) Self {
        return Self {
            .state = seed,
        };
    }

    pub fn next(self: *Self) u32 {
        self.state ^= self.state << 13;
        self.state ^= self.state >> 17;
        self.state ^= self.state << 5;
        return self.state;
    }
};
