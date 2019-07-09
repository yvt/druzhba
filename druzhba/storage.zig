const assert = @import("std").debug.assert;

/// Create a type representing a raw memory storage with the specified size and
/// alignment requirement.
pub fn AlignedStorage(comptime size: usize, comptime alignment: u29) type {
    // For now there doesn't exist a way to directly set a struct's alignment:
    // <https://github.com/ziglang/zig/issues/1512>
    var MaybeAligner: ?type = null;

    for (known_types) |KT| {
        if (alignment == @alignOf(KT)) {
            MaybeAligner = KT;
        }
    }

    if (MaybeAligner == null) {
        @compileError("could not find a type with the requested alignment");
    }

    const Aligner = MaybeAligner.?;

    // Compiler bug: Defining this using `union` causes `unable to evaluate
    //               constant expression for some reason
    const Ty = extern struct {
        aligner: Aligner,
        storage: [if (size < @sizeOf(Aligner)) 0 else size - @sizeOf(Aligner)]u8,

        const Self = @This();

        pub fn toBytes(self: *Self) [*]align(alignment) u8 {
            // Compiler bug: Ref-based slice (`ConstPtrSpecialRef`) is always
            //               treated as having 1 element, irregardless of
            //               reinterpretation. Because of this, returning
            //               `[]align(alignment) u8` causes various problems.
            return @ptrCast([*]align(alignment) u8, self);
            // return @ptrCast([*]align(alignment) u8, self)[0..size];
        }
    };

    assert(@sizeOf(Ty) >= size);
    assert(@alignOf(Ty) >= alignment);

    return Ty;
}

/// Types with variety of alignment requirements.
const known_types = [_]type{
    u8, u16, u32, u64,
};

/// Create a tuple type (heterogeneous fixed-size list type).
pub fn Tuple(comptime types: []const type) type {
    return if (types.len == 0) TupleEmpty else TupleNonEmpty(types);
}

const TupleEmpty = struct {
    const Self = @This();

    pub fn Elem(comptime i: usize) type {
        @compileError("out of bounds");
    }

    pub inline fn get(self: *Self, comptime i: usize) void {
        @compileError("out of bounds");
    }

    pub inline fn getConst(self: *const Self, comptime i: usize) void {
        @compileError("out of bounds");
    }
};

fn TupleNonEmpty(comptime types: []const type) type {
    return struct {
        head: Head,
        rest: Rest,

        const Self = @This();
        const Head = types[0];
        const Rest = Tuple(types[1 ..]);

        pub fn Elem(comptime i: usize) type {
            return if (i == 0) Head else Rest.Elem(i - 1);
        }

        pub inline fn get(self: *Self, comptime i: usize) *Elem(i) {
            return if (i == 0) &self.head else self.rest.get(i - 1);
        }

        pub inline fn getConst(self: *const Self, comptime i: usize) *const Elem(i) {
            return if (i == 0) &self.head else self.rest.getConst(i - 1);
        }
    };
}