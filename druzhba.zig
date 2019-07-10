const druzhba = @import("druzhba/druzhba.zig");

pub const defineSig = druzhba.defineSig;
pub const defineClass = druzhba.defineClass;
pub const Cell = druzhba.Cell;
pub const Class = druzhba.Class;
pub const Sig = druzhba.Sig;
pub const InPort = druzhba.InPort;
pub const OutPort = druzhba.OutPort;
pub const ComposeCtx = druzhba.ComposeCtx;
pub const Compose = druzhba.Compose;
pub const VtableFactory = druzhba.VtableFactory;
pub const ImplFactory = druzhba.ImplFactory;

test "unit tests" {
    _ = @import("druzhba/comptimeutils.zig");
    _ = @import("druzhba/druzhba.zig");
    _ = @import("druzhba/math.zig");
    _ = @import("druzhba/storage.zig");
}
