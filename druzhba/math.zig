const assert = @import("std").debug.assert;
const math = @import("std").math;

pub fn roundUpAlign(p: usize, a: usize) usize {
    assert(math.isPowerOfTwo(a));

    return (p | (a - 1)) & ~(a - 1);
}
