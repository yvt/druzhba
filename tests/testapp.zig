const testing = @import("std").testing;
const druzhba = @import("druzhba");

const GetU32 = druzhba.defineSig(struct {
    fn ___(comptime Self: type) type {
        return struct {
            pub get: fn (Self, u32) u32,
        };
    }
}.___);

const DeepThought = druzhba.defineClass()
    .attr(u32)
    .attrDefault(42)
    .state(u32) // dummy
    .in("answer", GetU32, struct {
        fn ___(comptime Self: type) type {
            return struct {
                pub fn get(self: Self, _: u32) u32 {
                    return self.attr().*;
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
    .state(u8) // dummy
    .out("answer", GetU32)
    .in("main", Entrypoint, struct {
        fn ___(comptime Self: type) type {
            return struct {
                pub fn main(self: Self) void {
                    const answer = self.out("answer").invoke("get", u32(114514));
                    testing.expectEqual(u32(42), answer);
                }
            };
        }
    }.___)
    .build();

fn addSystem(comptime ctx: *druzhba.ComposeCtx) void {
    const deepThought = ctx.new(DeepThought);
    const app = ctx.new(App);
    const port = druzhba.wrapTrace(ctx, deepThought.in("answer"), "seek answer");
    ctx.connect(app.out("answer"), port);
    ctx.entry(app.in("main"));
}

const System = druzhba.Compose(addSystem);
var system_state: System.State() = undefined;
const system = comptime System.link(&system_state);

test "Test app runs as intended" {
    system.init();
    system.invoke("main");
}
