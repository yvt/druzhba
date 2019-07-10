const builtin = @import("builtin");
const warn = @import("std").debug.warn;

const druzhba = @import("../druzhba.zig");
const intToStr = @import("../comptimeutils.zig").intToStr;

// Please do not run `zig fmt` on this source... It makes chained fn calls ugly.

const traceInPortName = "port";
const traceOutPortName = "port";

/// Create a class that logs method calls via `std.debug.warn`.
///
/// The class has two ports: an inbound port and an outbound port, both named
/// `port` and having the signature `sig`. All method invocations on the inbound
/// ports are forwarded to the outbound port. Before and after method calls are
/// forwarded, their method names and parameter values as well as an optional
/// custom label specified via an attribute are written to `std.debug.warn`.
///
/// Beware that parameters and return values are outputted simply by calling
/// `std.debug.warn`. This means all pointers within them are assumed to be
/// valid. Since this component is intended to be used only during development,
/// this shouldn't be a big problem.
pub fn Trace(comptime Sig: druzhba.Sig) druzhba.Class {
    return druzhba.defineClass()
        .attr(?[]const u8)
        .in(traceInPortName, Sig, struct {
            fn ___(comptime Self: type) type {
                return struct {
                    pub fn __vtable__() Sig.Vtable(Self) {
                        const Vtable = Sig.Vtable(Self);
                        comptime var vtable: Vtable = undefined;

                        comptime {
                            var i = 0;
                            while (i < @memberCount(Vtable)) {
                                const name = @memberName(Vtable, i);
                                const FnType = @memberType(Vtable, i);
                                @field(vtable, name) = @field(
                                    traceOneMethod(Self, FnType, name),
                                    "call" ++ intToStr(argCount(FnType) - 1),
                                );
                                i += 1;
                            }
                        }

                        return vtable;
                    }
                };
            }
        }.___)
        .out(traceOutPortName, Sig)
        .build();
}

pub const TraceIo = struct {
    in_port: druzhba.InPort,
    out_port: druzhba.OutPort,
};

/// Add a trace component.
pub fn addTrace(
    comptime ctx: *druzhba.ComposeCtx,
    comptime Sig: druzhba.Sig,
    comptime label: ?[]const u8,
) TraceIo {
    const cell = ctx.new(Trace(Sig)).withAttr(label);
    return TraceIo {
        .in_port = cell.in("port"),
        .out_port = cell.out("port"),
    };
}

/// Attach a trace component to the specified `InPort` or `OutPort`, and returns
/// a port of the same type.
pub fn wrapTrace(
    comptime ctx: *druzhba.ComposeCtx,
    comptime port: var,
    comptime label: ?[]const u8,
) @typeOf(port) {

    if (@typeOf(port) == druzhba.InPort) {
        const io = addTrace(ctx, port.PortSig(), label);
        ctx.connect(io.out_port, port);
        return io.in_port;
    } else if (@typeOf(port) == druzhba.OutPort) {
        const io = addTrace(ctx, port.PortSig(), label);
        ctx.connect(port, io.in_port);
        return io.out_port;
    } else {
        @compileError(@typeName(@typeOf(port)) ++ " is neither `InPort` nor `OutPort`.");
    }
}

/// Generates the implementation for a single method handled by `Trace`.
fn traceOneMethod(comptime Self: type, comptime Fn: type, comptime method_name: []const u8) type {
    const Ret = Fn.ReturnType;
    const A0 = ArgType(Fn, 1);
    const A1 = ArgType(Fn, 2);
    const A2 = ArgType(Fn, 3);
    const A3 = ArgType(Fn, 4);
    const A4 = ArgType(Fn, 5);
    const A5 = ArgType(Fn, 6);

    return struct {
        fn call0(self: Self) Ret {
            traceEnter(self, method_name);
            return traceLeave(self, method_name,
                self.out(traceOutPortName).invoke(method_name));
        }
        fn call1(self: Self, a0: A0) Ret {
            traceEnter(self, method_name, a0);
            return traceLeave(self, method_name,
                self.out(traceOutPortName).invoke(method_name, a0),
                a0);
        }
        fn call2(self: Self, a0: A0, a1: A1) Ret {
            traceEnter(self, method_name, a0, a1);
            return traceLeave(self, method_name,
                self.out(traceOutPortName).invoke(method_name, a0, a1),
                a0, a1);
        }
        fn call3(self: Self, a0: A0, a1: A1, a2: A2) Ret {
            traceEnter(self, method_name, a0, a1, a2);
            return traceLeave(self, method_name,
                self.out(traceOutPortName).invoke(method_name, a0, a1, a2),
                a0, a1, a2);
        }
        fn call4(self: Self, a0: A0, a1: A1, a2: A2, a3: A3) Ret {
            traceEnter(self, method_name, a0, a1, a2, a3);
            return traceLeave(self, method_name,
                self.out(traceOutPortName).invoke(method_name, a0, a1, a2, a3),
                a0, a1, a2, a3);
        }
        fn call5(self: Self, a0: A0, a1: A1, a2: A2, a3: A3, a4: A4) Ret {
            traceEnter(self, method_name, a0, a1, a2, a3, a4);
            return traceLeave(self, method_name,
                self.out(traceOutPortName).invoke(method_name, a0, a1, a2, a3, a4),
                a0, a1, a2, a3, a4);
        }
        fn call6(self: Self, a0: A0, a1: A1, a2: A2, a3: A3, a4: A4, a5: A5) Ret {
            traceEnter(self, method_name, a0, a1, a2, a3, a4, a5);
            return traceLeave(self, method_name,
                self.out(traceOutPortName).invoke(method_name, a0, a1, a2, a3, a4, a5),
                a0, a1, a2, a3, a4, a5);
        }
        // TODO: more parameters...
    };
}

fn argCount(comptime ty: type) usize {
    switch (@typeInfo(ty)) {
        builtin.TypeId.Fn => |fn_info| {
            return fn_info.args.len;
        },
        else => @compileError("not a function type"),
    }
}

fn ArgType(comptime ty: type, comptime i: usize) type {
    switch (@typeInfo(ty)) {
        builtin.TypeId.Fn => |fn_info| {
            if (i < fn_info.args.len) {
                return fn_info.args[i].arg_type.?;
            } else {
                return void;
            }
        },
        else => @compileError("not a function type"),
    }
}

fn traceEnter(self: var, method_name: []const u8, args: ...) void {
    traceCommon(self, "enter", method_name, args);
    warn("\n");
}
fn traceLeave(self: var, method_name: []const u8, ret_value: var, args: ...) @typeOf(ret_value) {
    traceCommon(self, "leave", method_name, args);
    warn(" = ");
    debugValue(ret_value);
    warn("\n");
    return ret_value;
}

fn traceCommon(self: var, dir: []const u8, method_name: []const u8, args: ...) void {
    if (self.attr().*) |label| {
        warn("{}", label);
    }
    warn(" [{}] {}(", dir, method_name);
    if (args.len > 0) {
        debugValue(args[0]);
        comptime var i = 1;
        inline while (i < args.len) {
            warn(", ");
            debugValue(args[i]);
            i += 1;
        }
    }
    warn(")");
}

fn debugValue(val: var) void {
    // Compiler bug: Var args can't handle void
    //               <https://github.com/ziglang/zig/issues/557>
    if (@typeOf(val) == void) {
        warn("void");
    } else {
        warn("{}", val);
    }
}