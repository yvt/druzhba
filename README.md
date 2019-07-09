# Druzhba

[ˈdruʐbə] with a rolled R

An experimental statically-composed toy component framework written in [Zig].

[Zig]: https://github.com/ziglang/zig

```zig
const druzhba = @import("druzhba");

const Counter = @import("components.zig").Counter;
const composeApp = @import("components.zig").composeApp;

fn composeSystem(comptime ctx: *druzhba.ComposeCtx) void {
    // Instantiate a cell (the smallest unit of encapsulation and message passing)
    const counter = ctx.new(Counter).withAttr(100);
    const counter_in_count = counter.in("count");

    // Instantiate a subsystem
    const app = composeApp(ctx);

    // Wire things up
    ctx.connect(app.out_count, counter_in_count);
    ctx.entry(app.in_main);
}

// Realize the system
const System = druzhba.Compose(composeSystem);
var system_state: System.State() = undefined;       // → RAM
const system = comptime System.link(&system_state); // → ROM

pub fn main() !void {
    // Initialize the system and call the entry point (`app.in_main.main`)
    system.init();
    system.invoke("main");
}
```

## Usage

**To run the example app**: `zig build run`

**To use it in your application**: Since Zig [doesn't have a package manager yet], import this repository as a Git submodule. Add `exe.addPackagePath("druzhba", "path/to/druzhba.zig")` to your `build.zig`.

[doesn't have a package manager yet]: https://github.com/ziglang/zig/issues/943

## What is this?

### Statically-composed component framework

> “[Component-based software engineering (CBSE)] is a reuse-based approach to defining, implementing and composing loosely coupled independent components into systems.” — [Component-based software engineering - Wikipedia](https://en.wikipedia.org/wiki/Component-based_software_engineering)

Component-based development is realized with the help of a software framework such as AUTOSAR, COM, and JavaBeans. Traditionally, they have been designed for run-time composition of components, meaning components and connections between them are constructed at run-time. For systems that don't change at run-time, this is an unnecessary overhead — it increases the system boot time, reduces the opportunity for compiler optimization, defers error checks, prevents the use of ROM (which is more abundant than RAM in microcontrollers), reduces the system security, and makes memory consumption harder to predict.

Statically-composed component frameworks are designed to address this problem. Components are instantiated based on a system description provided in a format the framework can process without a run-time knowledge. Their memory layouts are statically determined, and method calls between components are realized as direct function calls (when possible), only leaving run-time data that is absolutely necessary. There are [a few academic] [researches] focusing on such frameworks, showing their benefits for real-time and/or embedded systems.

[a few academic]: https://www.researchgate.net/publication/4141028_Static_composition_of_service-based_real-time_applications
[researches]: https://ieeexplore.ieee.org/abstract/document/4208825/

### Zig

[Zig] is a system programming language with a powerful compile-time reflection and evaluation feature. One possible way to explain it is that Zig is a fresh take on C/C++ metaprogramming — it provides access to low-level memory operations (including unsafe ones) like C/C++ do, but instead of C's lexical macros and C++'s template metaprogramming as well as gazillions of its retrofitted features, Zig offers a simple yet powerful feature set for metaprogramming that does the same or better job. This project (ab)uses it to create a statically-composed component framework.

[Zig]: https://ziglang.org

I did not choose Rust for this project because it would not be interesting. Rust is much limited on regard to metaprogramming. Macros in Rust are just macros after all and do not have access to the information outside the locations where they are used. A build script could be used to generate code, but it lacks novelty as it is no different from what existing solutions do. Furthermore, whichever way I choose, I would have to implement its own module resolution system when the language already has one.

## License

This project is dual-licensed under the Apache License Version 2.0 and the MIT License.
