const builtin = @import("builtin");

const testing = @import("std").testing;

// TODO: I wish I could write something like `{ ...self, ._state = ty }`
pub fn setField(lhs: var, comptime field_name: []const u8, value: var) @typeOf(lhs) {
    var new = lhs;
    @field(new, field_name) = value;
    return new;
}

test "setField updates a field and returns a brand new struct" {
    const x = setField(struct {
            a: u32,
            b: u32,
        }{
        .a = 42,
        .b = 84,
    }, "a", 100);

    testing.expectEqual(u32(100), x.a);
    testing.expectEqual(u32(84), x.b);
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

test "append appends a new element" {
    comptime {
        const s0 = empty(u32);
        const s1 = append(s0, 100);
        testing.expectEqual([]const u32, @typeOf(s1));
        testing.expectEqual(100, s1[0]);
        const s2 = append(s1, 200);
        testing.expectEqual([]const u32, @typeOf(s2));
        testing.expectEqual(100, s2[0]);
        testing.expectEqual(200, s2[1]);
    }
}

pub fn empty(comptime ty: type) []const ty {
    return [_]ty{};
}

test "empty produces an empty slice" {
    comptime {
        testing.expectEqual(empty(u32).len, 0);
    }
}

pub fn map(comptime To: type, comptime transducer: var, comptime slice: var) [slice.len]To {
    var ret: [slice.len]To = undefined;

    for (slice) |*e, i| {
        ret[i] = transducer(e);
    }

    return ret;
}

test "map does its job" {
    comptime {
        const array1 = map(u8, struct {
            fn ___(x: *const u32) u8 {
                return undefined;
            }
        }.___, empty(u8));
        testing.expectEqual([0]u8, @typeOf(array1));
        testing.expectEqualSlices(u8, &[_]u8{}, &array1);

        const array2 = map(u8, struct {
            fn ___(x: *const u32) u8 {
                return @truncate(u8, x.*) + 1;
            }
        }.___, [_]u32{ 1, 2, 3 });
        testing.expectEqual([3]u8, @typeOf(array2));
        testing.expectEqualSlices(u8, &[_]u8{ 2, 3, 4 }, &array2);
    }
}
