const testing = @import("std").testing;
const druzhba = @import("druzhba");

// This system does not include any cell states. I saw some cases where it
// caused ICE. It is very unlikely to occur in a real world situation, but
// bugs are bugs.

const GetU32 = druzhba.defineSig(struct {
    fn ___(comptime Self: type) type {
        return struct {
            pub get: fn (Self) u32,
        };
    }
}.___);

const DeepThought = druzhba.defineClass()
    .in("answer", GetU32, struct {
        fn ___(comptime Self: type) type {
            return struct {
                pub fn get(self: Self) u32 {
                    return 42;
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
    .out("answer", GetU32)
    .in("main", Entrypoint, struct {
        fn ___(comptime Self: type) type {
            return struct {
                pub fn main(self: Self) void {
                    const answer = self.out("answer").invoke("get");
                    testing.expectEqual(u32(42), answer);
                }
            };
        }
    }.___)
    .build();

fn composeSystem(comptime ctx: *druzhba.ComposeCtx) void {
    const deepThought = ctx.new(DeepThought);
    const app = ctx.new(App);
    ctx.connect(app.out("answer"), deepThought.in("answer"));
    ctx.entry(app.in("main"));
}

const System = druzhba.Compose(composeSystem);
var system_state: System.State() = undefined;
const system = comptime System.link(&system_state);

test "Stateless app runs as intended" {
    system.init();
    system.invoke("main");
}
