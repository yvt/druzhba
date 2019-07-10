const std = @import("std");
const druzhba = @import("druzhba");

// Please do not run `zig fmt` on this source... It makes chained fn calls ugly.

/// Signature `Count` — Provides a method to decrement a counter value.
const Count = druzhba.defineSig(struct {
    fn ___(comptime Self: type) type {
        return struct {
            /// Decrement the counter value and return the new value.
            pub next: fn (Self) u32,
        };
    }
}.___);

/// Cell class `Counter` — Implements `Count`.
const Counter = druzhba.defineClass()
    .state(u32)
    .attr(u32)
    // Set the `ctor` method of the class. Use it to initialize `state`.
    .ctor(struct {
        fn ___(self: var) void {
            const state: *u32 = self.state();
            const attr: *const u32 = self.attr();
            state.* = attr.*;
            std.debug.warn("Counter: The counter value was initialized to {}\n", self.attr().*);
        }
    }.___)
    // Defines an inbound port of signature `Count`.
    .in("count", Count, struct {
        fn ___(comptime Self: type) type {
            return struct {
                // This is one of the two ways to provide an implementation.
                // Less handy, but good for metaprogramming.
                pub fn __vtable__() Count.Vtable(Self) {
                    return Count.Vtable(Self) { .next = next };
                }

                /// The implementation of the `next` method.
                fn next(self: Self) u32 {
                    const state: *u32 = self.state();
                    state.* -= 1;
                    return state.*;
                }
            };
        }
    }.___)
    .build();

/// Signature `Entrypoint` — Provides an entrypoint method to be called from
/// the main function (hosted environment), reset handler, or interrupt handlers
/// (bare metal).
const Entrypoint = druzhba.defineSig(struct {
    fn ___(comptime Self: type) type {
        return struct {
            pub main: fn (Self) void,
        };
    }
}.___);

/// Cell class `App` — The example application.
const App = druzhba.defineClass()
    // Defines an outbound port of signature `Count`.
    .out("count", Count)
    // Defines an inbound port of signature `Entrypoint`.
    .in("main", Entrypoint, struct {
        fn ___(comptime Self: type) type {
            return struct {
                pub fn main(self: Self) void {
                    const count = self.out("count");

                    // https://www.derpibooru.org/2078751
                    var i = count.invoke("next");

                    while (i > 0) {
                        const i_next = count.invoke("next");
                        if (i != 1) {
                            std.debug.warn("{} bottles of pop on the wall, {} bottles of pop.\n", i, i);
                        } else {
                            std.debug.warn("{} bottle of pop on the wall, {} bottle of pop.\n", i, i);
                        }
                        if (i_next != 1) {
                            std.debug.warn("Take one down, pass it around, {} bottles of pop on the wall.\n", i_next);
                        } else {
                            std.debug.warn("Take one down, pass it around, {} bottle of pop on the wall.\n", i_next);
                        }
                        std.debug.warn("\n");

                        i = i_next;
                    }
                }
            };
        }
    }.___)
    .build();

/// The inbound/outbound ports exposed by the subsystem `addApp`.
const AppIo = struct {
    in_main: druzhba.InPort,
    out_count: druzhba.OutPort,
};

/// This demonstrates how to define a subsystem.
fn addApp(comptime ctx: *druzhba.ComposeCtx) AppIo {
    const app = ctx.new(App);
    return AppIo {
        .in_main = app.in("main"),
        .out_count = app.out("count"),
    };
}

/// The compose function, where classes are instantiated and connections are
/// defined.
fn addSystem(comptime ctx: *druzhba.ComposeCtx) void {
    // Instantiate a `Counter` cell.
    const counter = ctx.new(Counter).withAttr(100);

    // Instantiate the `App` subsystem.
    const app = addApp(ctx);

    // Wire things up
    ctx.connect(app.out_count, counter.in("count"));
    ctx.entry(app.in_main);
}

const System = druzhba.Compose(addSystem);
var system_state: System.State() = undefined;       // → RAM
const system = comptime System.link(&system_state); // → ROM

pub fn main() anyerror!void {
    // Call `ctor` methods of cells.
    system.init();

    // Invoke the `main` method of the inbound port `app.in_main`.
    system.invoke("main");
}
