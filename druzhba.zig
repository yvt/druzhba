const druzhba = @import("druzhba/druzhba.zig");

pub const defineSig = druzhba.defineSig;
pub const defineClass = druzhba.defineClass;
pub const Cell = druzhba.Cell;
pub const InPort = druzhba.InPort;
pub const OutPort = druzhba.OutPort;
pub const ComposeCtx = druzhba.ComposeCtx;
pub const Compose = druzhba.Compose;

test "unit tests" {
    _ = @import("druzhba/comptimeutils.zig");
    _ = @import("druzhba/druzhba.zig");
    _ = @import("druzhba/math.zig");
    _ = @import("druzhba/storage.zig");
}
