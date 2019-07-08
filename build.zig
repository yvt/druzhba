const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("druzhba", "examples/basic.zig");
    exe.setBuildMode(mode);
    exe.addPackagePath("druzhba", "src/druzhba.zig");

    const run_cmd = exe.run();

    const run_step = b.step("run", "Run the example app");
    run_step.dependOn(&run_cmd.step);

    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}
