const std = @import("std");
const druzhba = @import("druzhba");

// Please do not run `zig fmt` on this source... It makes chained fn calls ugly.

const Count = druzhba.defineSig(struct {
    fn ___(comptime Self: type) type {
        return struct {
            pub next: fn (Self) u32,
        };
    }
}.___);

const Counter = druzhba.defineClass()
    .state(u32)
    .attr(u32)
    .ctor(struct {
        fn ___(self: var) void {
            self.state().* = self.attr().*;
            std.debug.warn("Counter: The counter value was initialized to {}\n", self.attr().*);
        }
    }.___)
    .in("count", Count, struct {
        fn ___(comptime Self: type) type {
            return struct {
                pub fn next(self: Self) u32 {
                    const state = self.state();
                    state.* -= 1;
                    return state.*;
                }
            };
        }
    }.___)
    .build();

const Entrypoint = druzhba.defineSig(struct {
    fn ___(comptime Self: type) type {
        return struct {
            pub main: fn (Self) void,
        };
    }
}.___);

const App = druzhba.defineClass()
    .out("count", Count)
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

const AppIo = struct {
    main: druzhba.InPort,
    count: druzhba.OutPort,
};

fn composeApp(comptime ctx: *druzhba.ComposeCtx) AppIo {
    const app = ctx.new(App);
    return AppIo {
        .main = app.in("main"),
        .count = app.out("count"),
    };
}

fn composeSystem(comptime ctx: *druzhba.ComposeCtx) void {
    const counter = ctx.new(Counter).withAttr(100);
    const app = composeApp(ctx);
    ctx.connect(app.count, counter.in("count"));
    ctx.entry(app.main);
}

const System = druzhba.Compose(composeSystem);
var system_state: System.State() = undefined;
const system = comptime System.link(&system_state);

pub fn main() anyerror!void {
    system.init();
    _ = system.invoke("main");
}
