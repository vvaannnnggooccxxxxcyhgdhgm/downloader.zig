const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the downloader module (for internal usage)
    const downloader_mod = b.createModule(.{
        .root_source_file = b.path("src/downloader.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Expose the module for external projects that depend on this package
    _ = b.addModule("downloader", .{
        .root_source_file = b.path("src/downloader.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Unit tests
    const lib_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/downloader.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_tests.step);

    // Example executable - basic
    const basic_example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/basic.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "downloader", .module = downloader_mod },
            },
        }),
    });

    const install_basic = b.addInstallArtifact(basic_example, .{});
    b.getInstallStep().dependOn(&install_basic.step);

    const run_basic = b.addRunArtifact(basic_example);
    run_basic.step.dependOn(&install_basic.step);

    if (b.args) |args| {
        run_basic.addArgs(args);
    }

    const run_step = b.step("run", "Run the basic example");
    run_step.dependOn(&run_basic.step);

    // All examples configuration
    const examples = [_]struct { name: []const u8, src: []const u8 }{
        .{ .name = "advanced", .src = "examples/advanced.zig" },
        .{ .name = "concurrent", .src = "examples/concurrent.zig" },
        .{ .name = "resume", .src = "examples/resume.zig" },
        .{ .name = "checksum", .src = "examples/checksum.zig" },
        .{ .name = "update_check", .src = "examples/update_check.zig" },
    };

    // Run-all-examples step
    const run_all_step = b.step("run-all-examples", "Run all example programs");

    // Add basic example to run-all
    run_all_step.dependOn(&run_basic.step);

    for (examples) |ex| {
        const exe = b.addExecutable(.{
            .name = ex.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(ex.src),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "downloader", .module = downloader_mod },
                },
            }),
        });

        const install_exe = b.addInstallArtifact(exe, .{});
        b.getInstallStep().dependOn(&install_exe.step);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(&install_exe.step);
        if (b.args) |args| run_cmd.addArgs(args);

        const step_name = b.fmt("run-{s}", .{ex.name});
        const step_desc = b.fmt("Run the {s} example", .{ex.name});
        const step = b.step(step_name, step_desc);
        step.dependOn(&run_cmd.step);

        // Add to run-all-examples step
        run_all_step.dependOn(&run_cmd.step);
    }

    // Documentation generation
    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib_tests.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Generate Zig documentation");
    docs_step.dependOn(&install_docs.step);
}
