const std = @import("std");
const druzhba = @import("druzhba");

pub fn main() anyerror!void {
    std.debug.warn("All your base are belong to us.\n");
    std.debug.warn("{}\n", druzhba.hoge);
}
