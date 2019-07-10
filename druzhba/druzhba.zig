const builtin = @import("builtin");

const std = @import("std");
const mem = std.mem;
const sort = std.sort.sort;

const comptimeutils = @import("comptimeutils.zig");
const setField = comptimeutils.setField;
const append = comptimeutils.append;
const empty = comptimeutils.empty;
const map = comptimeutils.map;

const mathutils = @import("math.zig");
const roundUpAlign = mathutils.roundUpAlign;

const storageutils = @import("storage.zig");
const AlignedStorage = storageutils.AlignedStorage;
const Tuple = storageutils.Tuple;

// Defining classes and signatures
// --------------------------------------------------------------------------

/// Define a signature.
pub fn defineSig(comptime Factory: VtableFactory) Sig {
    // Non-comprehensive check, so easy to bypass
    const Marker = struct {
        blah: usize,
    };

    switch (@typeInfo(Factory(Marker))) {
        builtin.TypeId.Struct => |info| {
            for (info.fields) |field| {
                switch (@typeInfo(field.field_type)) {
                    builtin.TypeId.Fn => |fn_info| {
                        if (fn_info.args.len == 0) {
                            @compileError(field.name ++ " doesn't have a receiver parameter");
                        } else if (fn_info.args[0].is_generic) {
                            @compileError(field.name ++ " has an invalid receiver type. Got: (generic)");
                        } else if (fn_info.args[0].arg_type.? != Marker) {
                            @compileError(field.name ++ " has an invalid receiver type. Got: " ++
                                @typeName(fn_info.args[0].arg_type));
                        }
                    },
                    else => @compileError(field.name ++ " is not a function type"),
                }
            }
        },
        else => @compileError("must specify a struct type"),
    }

    return Sig{
        .VtableFactory = Factory,
    };
}

pub const Sig = struct {
    VtableFactory: VtableFactory,

    const Self = @This();

    /// Make a vtable type for the specified receiver type.
    ///
    /// This is a user-facing API.
    pub fn Vtable(comptime self: Self, comptime VtSelf: type) type {
        return self.VtableFactory(VtSelf);
    }
};

const Method = struct {
    name: []const u8,
    func: builtin.TypeInfo.Fn,
};

/// Start defining a cell class.
pub fn defineClass() ClassBuilder {
    return ClassBuilder{};
}

/// The builder type used to define a cell class.
const ClassBuilder = struct {
    // Compiler bug: Changing this to `void` causes assertion failure.
    //               The root cause is not identified yet.
    _StateTy: type = u8,
    _AttrTy: type = void,
    built: bool = false,
    in_ports: []const InPortInfo = empty(InPortInfo),
    out_ports: []const OutPortInfo = empty(OutPortInfo),
    _ctor: fn (var) void = defaultCtor,
    _AttrInit: ValueFactory = MakeValueFactory({}),

    const Self = @This();

    fn defaultCtor(self: var) void {}

    /// Set the state type of the class. It defaults to `void`.
    pub fn state(comptime self: Self, comptime ty: type) Self {
        return setField(self, "_StateTy", ty);
    }

    /// Set the attribute type of the class. It defaults to `void`.
    pub fn attr(comptime self: Self, comptime ty: type) Self {
        return setField(self, "_AttrTy", ty);
    }

    /// Set the default value of the attribute. It defaults to `{}`.
    pub fn attrDefault(comptime self: Self, comptime value: var) Self {
        return setField(self, "_AttrInit", MakeValueFactory(value));
    }

    /// Set the constructor function of the class.
    ///
    /// Construction functions are automatically called for all cells when a
    /// system is instantiated.
    pub fn ctor(comptime self: Self, comptime impl: fn (var) void) Self {
        return setField(self, "_ctor", impl);
    }

    /// Define an outbound port.
    pub fn out(comptime self: Self, comptime name: []const u8, comptime sig: Sig) Self {
        return setField(self, "out_ports", append(self.out_ports, OutPortInfo{
            .name = name,
            .sig = sig,
        }));
    }

    /// Define an inbound port as well as its handler functions.
    pub fn in(comptime self: Self, comptime name: []const u8, comptime sig: Sig, comptime Factory: ImplFactory) Self {
        return setField(self, "in_ports", append(self.in_ports, InPortInfo{
            .name = name,
            .sig = sig,
            .ImplFactory = Factory,
        }));
    }

    /// Finalize the `ClassBuilder`.
    pub fn build(comptime self: Self) Class {
        return Class{
            .StateTy = self._StateTy,
            .AttrTy = self._AttrTy,
            .built = self.built,
            .in_ports = self.in_ports,
            .out_ports = self.out_ports,
            .ctor = self._ctor,
            .DefaultAttrInit = self._AttrInit,
        };
    }
};

pub const Class = struct {
    StateTy: type,
    AttrTy: type,
    built: bool,
    in_ports: []const InPortInfo,
    out_ports: []const OutPortInfo,
    ctor: fn (var) void,
    DefaultAttrInit: ValueFactory,

    const Self = @This();

    /// Get a reference to the specified outbound port.
    pub fn out_port_info(comptime self: Self, comptime name: []const u8) *const OutPortInfo {
        return &self.out_ports[self.out_port_i(name)];
    }

    /// Get an index of the specified outbound port.
    pub fn out_port_i(comptime self: Self, comptime name: []const u8) usize {
        for (self.out_ports) |*out_port, i| {
            if (mem.eql(u8, out_port.name, name)) {
                return i;
            }
        }

        @compileError("unknown outbound port name: " ++ name);
    }
};

/// A function that produces a type containing the fields for the handler
/// functions of a signature. The given type is used as their receiver type.
///
/// (They can be automatically generated from a prototype that doesn't
/// have a receiver parameter once <https://github.com/ziglang/zig/issues/383>
/// lands.)
pub const VtableFactory = fn (type) type;

/// A function that produces a type containing the handler functions of a
/// signature. The parameter type `VtSelf` is used as their receiver type.
///
/// The handler functions are provided by the type in one of the following ways:
///
///  - Function declarations with corresponding method names. The functions must
///    accept `self: VtSelf` as the first parameter.
///
///  - A single function declaration named `__vtable__`, having type
///    `fn () sig.Vtable(VtSelf)`, where `sig` represents a signature and is
///    a value of type `Sig`. The return value is a raw vtable and must be
///    `comptime`-known.
///
/// The second usage is an advanced feature intended to be used for
/// metaprogramming. For example, it can be used to automatically generate
/// an implementation from a signature.
pub const ImplFactory = fn (type) type;

const InPortInfo = struct {
    name: []const u8,
    sig: Sig,
    ImplFactory: ImplFactory,
};

const OutPortInfo = struct {
    name: []const u8,
    sig: Sig,
};

// Value producer
// --------------------------------------------------------------------------

/// A type-erased constant value producer.
const ValueFactory = type;

fn MakeValueFactory(value: var) ValueFactory {
    return struct {
        fn get(comptime T: type) T {
            if (@typeOf(value) == void and T != void) {
                @compileError("An attribute value of type " ++ @typeName(T) ++
                    " is required, but missing.");
            }
            return value;
        }
    };
}

// Defining a system
// --------------------------------------------------------------------------

/// Represents a reference to a cell defined in a `ComposeCtx`.
pub const Cell = struct {
    ctx: *ComposeCtx,
    cell_id: usize,

    const Self = @This();

    /// Get a reference to the specified inbound port of the cell.
    pub fn in(comptime self: Self, comptime name: []const u8) InPort {
        const class = &self.getInner().class;

        for (class.in_ports) |in_port, i| {
            if (mem.eql(u8, in_port.name, name)) {
                return InPort{ .cell_id = self.cell_id, .in_port_id = i };
            }
        }

        @compileError("unknown inbound port name: " ++ name);
    }

    /// Get a reference to the specified outbound port of the cell.
    pub fn out(comptime self: Self, comptime name: []const u8) OutPort {
        const class = &self.getInner().class;

        for (class.out_ports) |out_port, i| {
            if (mem.eql(u8, out_port.name, name)) {
                return OutPort{ .cell_id = self.cell_id, .out_port_id = i };
            }
        }

        @compileError("unknown outbound port name: " ++ name);
    }

    /// Set the attribute value of the cell.
    pub fn withAttr(comptime self: Self, value: self.getInner().class.AttrTy) Self {
        const inner = self.getInner();

        inner.AttrInit = MakeValueFactory(value);

        return self;
    }

    fn getInner(comptime self: *const Self) *ComposeCtxCell {
        return self.ctx.cells[self.cell_id];
    }
};

/// Represents a reference to an inbound port of a cell defined in
/// a `ComposeCtx`.
pub const InPort = struct {
    cell_id: usize,
    in_port_id: usize,
};

/// Represents a reference to an outbound port of a cell defined in
/// a `ComposeCtx`.
pub const OutPort = struct {
    cell_id: usize,
    out_port_id: usize,
};

const ComposeCtxCell = struct {
    class: Class,

    /// The initializer for the cell's attribute.
    AttrInit: ValueFactory,
};

const ComposeCtxConn = struct {
    out: OutPort,
    in: InPort,
};

pub const ComposeCtx = struct {
    cells: []const *ComposeCtxCell = empty(*ComposeCtxCell),
    conns: []const ComposeCtxConn = empty(ComposeCtxConn),
    entry_port: ?InPort = null,

    const Self = @This();

    /// Instantiate a cell of the specified class.
    pub fn new(comptime self: *Self, comptime class: Class) Cell {
        const cell_id = self.cells.len;

        var cell = ComposeCtxCell{
            .class = class,
            .AttrInit = class.DefaultAttrInit,
        };
        self.cells = append(self.cells, &cell);

        return Cell{ .cell_id = cell_id, .ctx = self };
    }

    /// Create a connection between an outbound port and an inbound port.
    pub fn connect(comptime self: *Self, out: OutPort, in: InPort) void {
        self.conns = append(self.conns, ComposeCtxConn{
            .out = out,
            .in = in,
        });
    }

    /// Define the entrypoint.
    pub fn entry(comptime self: *Self, in: InPort) void {
        self.entry_port = in;
    }
};

// Implementing a system
// --------------------------------------------------------------------------

/// Construct a "system" type from a compose function.
pub fn Compose(comptime desc: fn (*ComposeCtx) void) type {
    var ctx = ComposeCtx{};
    comptime desc(&ctx);

    const state_layout = layoutState(ctx.cells);
    const StateTy = AlignedStorage(state_layout.size, state_layout.alignment);

    return struct {
        state: []align(state_layout.alignment) u8,

        const Self = @This();

        /// Get the type for storing the state of the system.
        ///
        /// The application should create a global variable of this type,
        /// initialized with `undefined`. The address to the global variable
        /// must be explicitly supplied to `link` so that its address can be
        /// known.
        pub fn State() type {
            return StateTy;
        }

        /// Hoge
        pub fn link(state: *StateTy) Self {
            return Self{ .state = state.toBytes() };
        }

        /// Invoke the constructors.
        pub fn init(comptime self: *const Self) void {
            inline for (ctx.cells) |cell, cell_id| {
                const cell_static = comptime self.cellStatic(cell_id);
                cell.class.ctor(cell_static);
            }
        }

        /// Invoke an entrypoint method.
        pub fn invoke(comptime self: *const Self, comptime name: []const u8, args: ...) InvokeReturnType(name) {
            const entry = ctx.entry_port.?;

            const cell = ctx.cells[entry.cell_id];
            const cell_static = comptime self.cellStatic(entry.cell_id);
            const vtable = comptime makeVtable(cell.class, entry.in_port_id, *const CellStaticOfCell(entry.cell_id));

            const func = @field(vtable, name);
            // Compiler bug: This crashes the compiler:
            //               `func(self.target_self, args)`
            switch (args.len) {
                0 => return func(cell_static),
                1 => return func(cell_static, args[0]),
                2 => return func(cell_static, args[0], args[1]),
                3 => return func(cell_static, args[0], args[1], args[2]),
                4 => return func(cell_static, args[0], args[1], args[2], args[3]),
                5 => return func(cell_static, args[0], args[1], args[2], args[3], args[4]),
                6 => return func(cell_static, args[0], args[1], args[2], args[3], args[4], args[5]),
                7 => return func(cell_static, args[0], args[1], args[2], args[3], args[4], args[5], args[6]),
                else => @compileLog("Too many arguments (cases only up to 7 are implemented)"),
            }
            return 42;
        }

        // Since return type inference isn't implemented yet...
        // <https://github.com/ziglang/zig/issues/447>
        fn InvokeReturnType(comptime name: []const u8) type {
            const entry = ctx.entry_port.?;

            const cell = ctx.cells[entry.cell_id];
            const vtable = comptime makeVtable(cell.class, entry.in_port_id, *const CellStaticOfCell(entry.cell_id));

            return @typeOf(@field(vtable, name)).ReturnType;
        }

        fn CellStateOfCell(comptime cell_id: usize) type {
            return ctx.cells[cell_id].class.StateTy;
        }

        fn cellState(self: *const Self, comptime cell_id: usize) *CellStateOfCell(cell_id) {
            const off = comptime state_layout.cell_offs[cell_id];
            const T = CellStateOfCell(cell_id);
            if (@sizeOf(T) == 0) {
                return undefined;
            } else {
                const bytes = &self.state[off];
                return @ptrCast(*T, @alignCast(@alignOf(T), bytes));
            }
        }

        fn CellStaticOfCell(comptime cell_id: usize) type {
            return CellStatic(ctx.cells[cell_id].class);
        }

        /// Get a pointer to `CellStatic(cell_id)`.
        fn cellStatic(self: *const Self, comptime cell_id: usize) *const CellStaticOfCell(cell_id) {
            // Construct a `CellStatic`.
            var st: CellStaticOfCell(cell_id) = undefined;
            const cell = ctx.cells[cell_id];

            st._attr = cell.AttrInit.get(@typeOf(st._attr));
            st._state = self.cellState(cell_id);

            inline for (cell.class.out_ports) |*out_port, out_port_id| {
                // Find the corresponding inbound port
                // TODO: This is very inefficient
                // TODO: improve diagnostics
                const conn: ?ComposeCtxConn = comptime findConn(cell_id, out_port_id);
                if (conn == null) {
                    @compileError("each outbound port must have exactly one connection");
                }

                // TODO: see if circular reference works?
                const target_cell = ctx.cells[conn.?.in.cell_id];
                const target_cell_static = self.cellStatic(conn.?.in.cell_id);
                const target_vtable = comptime makeVtable(target_cell.class, conn.?.in.in_port_id, *const CellStaticOfCell(conn.?.in.cell_id));

                // Erase `*const CellStaticOfCell`
                const vtable_ty = @typeOf(st._out_port_vtables.get(out_port_id).*);
                const target_vtable_erased = @ptrCast(vtable_ty, &target_vtable);
                const target_cell_static_erased = @ptrCast(CellStaticErased, target_cell_static);

                st._out_port_vtables.get(out_port_id).* = target_vtable_erased;
                st._out_port_target_selves[out_port_id] = target_cell_static_erased;
            }

            return &st;
        }

        fn findConn(cell_id: usize, out_port_id: usize) ?ComposeCtxConn {
            var conn: ?ComposeCtxConn = null;
            for (ctx.conns) |c| {
                if (c.out.cell_id == cell_id and c.out.out_port_id == out_port_id) {
                    if (conn != null) {
                        return null;
                    }
                    conn = c;
                }
            }
            return conn;
        }
    };
}

// Dispatch
// --------------------------------------------------------------------------

/// Create a vtable for an inbound port.
///
/// The handler functions are instantiated using the receiver type `Self`. Thus,
/// `Self` must be appropriate for the context of `class`.
fn makeVtable(comptime class: Class, comptime in_port_id: usize, comptime Self: type) class.in_ports[in_port_id].sig.VtableFactory(Self) {
    const sig = class.in_ports[in_port_id].sig;
    const Vtable = sig.VtableFactory(Self);
    var vtable: Vtable = undefined;

    const Impl = class.in_ports[in_port_id].ImplFactory(Self);

    if (@hasDecl(Impl, "__vtable__")) {
        // Raw vtable mode - see `ImplFactory`'s documentation.'
        const vt = Impl.__vtable__();
        if (@typeOf(vt) != Vtable) {
            @compileError("`__vtable__()` returned a value of type " ++
                @typeName(@typeOf(vt)) ++ ", which is not a valid vtable type");
        }
        return vt;
    }

    comptime var i = 0;
    inline while (i < @memberCount(Vtable)) {
        const name = @memberName(Vtable, i);
        const func = @field(Impl, name);
        @field(vtable, name) = func;
        i += 1;
    }

    return vtable;
}

// Cell memory layout
// --------------------------------------------------------------------------

// TODO: Abstract and classify memory allocations into static and dynamic

/// A type-erased `*const CellStatic`.
const CellStaticErased = [*]const u8;

/// A structure containing the state, attributes, and outbound port vtables of
/// a cell.
///
/// This type can be used as a `Self` type of `makeVtable`.
fn CellStatic(comptime class: Class) type {
    return struct {
        _attr: class.AttrTy,
        _state: *class.StateTy,
        // TODO: Optimize, e.g., devirtualize
        _out_port_vtables: Tuple(map(type, struct {
            fn ___(comptime x: *const OutPortInfo) type {
                return *const x.sig.VtableFactory(CellStaticErased);
            }
        }.___, class.out_ports)),
        _out_port_target_selves: [class.out_ports.len]CellStaticErased,

        const Self = @This();

        pub fn attr(self: *const Self) *const class.AttrTy {
            return &self._attr;
        }

        pub fn state(self: *const Self) *class.StateTy {
            return self._state;
        }

        pub fn out(self: *const Self, comptime name: []const u8) CellStaticOut(class.out_port_info(name)) {
            const index = comptime class.out_port_i(name);
            return CellStaticOut(class.out_port_info(name)){
                .vtable = self._out_port_vtables.getConst(index).*,
                .target_self = self._out_port_target_selves[index],
            };
        }
    };
}

fn CellStaticOut(comptime out_port: *const OutPortInfo) type {
    return struct {
        vtable: *const out_port.sig.VtableFactory(CellStaticErased),
        target_self: CellStaticErased,

        const Self = @This();

        /// Invoke a method in an outbound port.
        pub fn invoke(self: Self, comptime name: []const u8, args: ...) @typeOf(@field(self.vtable, name)).ReturnType {
            const func = @field(self.vtable, name);
            // Compiler bug: This crashes the compiler:
            //               `func(self.target_self, args)`
            switch (args.len) {
                0 => return func(self.target_self),
                1 => return func(self.target_self, args[0]),
                2 => return func(self.target_self, args[0], args[1]),
                3 => return func(self.target_self, args[0], args[1], args[2]),
                4 => return func(self.target_self, args[0], args[1], args[2], args[3]),
                5 => return func(self.target_self, args[0], args[1], args[2], args[3], args[4]),
                6 => return func(self.target_self, args[0], args[1], args[2], args[3], args[4], args[5]),
                7 => return func(self.target_self, args[0], args[1], args[2], args[3], args[4], args[5], args[6]),
                else => @compileLog("Too many arguments (cases only up to 7 are implemented)"),
            }
        }
    };
}

// State memory layout
// --------------------------------------------------------------------------

const CellStateLayout = usize;
const StateLayout = struct {
    cell_offs: []const usize,
    size: usize,
    alignment: u29,
};

fn layoutState(comptime cells: []const *ComposeCtxCell) StateLayout {
    // Sort by alignment
    const Ent = struct {
        i: usize,
        alignment: u29,
        size: usize,
    };
    var ents: [cells.len]Ent = undefined;
    var count: usize = 0;
    for (cells) |cell, i| {
        if (@sizeOf(cell.class.StateTy) == 0) {
            continue;
        }
        const ent = Ent{
            .i = i,
            .size = @sizeOf(cell.class.StateTy),
            .alignment = @alignOf(cell.class.StateTy),
        };
        ents[count] = ent;
        count += 1;
    }

    sort(Ent, ents[0..count], struct {
        fn ___(lhs: Ent, rhs: Ent) bool {
            return lhs.alignment > rhs.alignment;
        }
    }.___);

    // Pack 'em
    var off: usize = 0;
    var cell_offs = [1]usize{0} ** cells.len;

    for (ents[0..count]) |ent| {
        off = roundUpAlign(off, ent.alignment);
        cell_offs[ent.i] = off;
        off += ent.size;
    }

    return StateLayout{
        .cell_offs = cell_offs,
        .size = off,
        .alignment = if (count > 0) ents[0].alignment else 1,
    };
}
