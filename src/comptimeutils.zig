const builtin = @import("builtin");

// TODO: I wish I could write something like `{ ...self, ._state = ty }`
pub fn setField(lhs: var, comptime field_name: []const u8, value: var) @typeOf(lhs) {
    var new = lhs;
    @field(new, field_name) = value;
    return new;
}

pub fn append(lhs: var, x: var) @typeOf(lhs) {
    switch (@typeInfo(@typeOf(lhs))) {
        builtin.TypeId.Pointer => |info| switch (info.size) {
            builtin.TypeInfo.Pointer.Size.Slice => {
                const elem_type = info.child;

                return lhs ++ ([_]elem_type{x})[0..1];
            },
            else => @compileError("lhs must be a slice"),
        },
        else => @compileError("lhs must be a slice"),
    }
}

pub fn empty(comptime ty: type) []const ty {
    return [_]ty{};
}

pub fn map(comptime To: type, comptime transducer: var, comptime slice: var) [slice.len]To {
    var ret: [slice.len]To = undefined;

    for (slice) |*e, i| {
        ret[i] = transducer(e);
    }

    return ret;
}
