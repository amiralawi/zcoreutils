const std = @import("std");
const builtin = @import("builtin");
// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.

    const optimize = b.standardOptimizeOption(.{});
    //const optimize = std.builtin.Mode.ReleaseSmall;

    const zargh = b.dependency("zargh", .{
        .optimize = optimize,
        .target = target,
    });

    const single_threaded = builtin.single_threaded;
    //var single_threaded = true;

    const exe = b.addExecutable(.{
        .name = "zls",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/zls.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).

    // additional executables
    const exe_zecho = b.addExecutable(.{
        .name = "zecho",
        .root_source_file = .{ .path = "src/zecho.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zhead = b.addExecutable(.{
        .name = "zhead",
        .root_source_file = .{ .path = "src/zhead.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_ztail = b.addExecutable(.{
        .name = "ztail",
        .root_source_file = .{ .path = "src/ztail.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zcat = b.addExecutable(.{
        .name = "zcat",
        .root_source_file = .{ .path = "src/zcat.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_ztouch = b.addExecutable(.{
        .name = "ztouch",
        .root_source_file = .{ .path = "src/ztouch.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zmkdir = b.addExecutable(.{
        .name = "zmkdir",
        .root_source_file = .{ .path = "src/zmkdir.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zrm = b.addExecutable(.{
        .name = "zrm",
        .root_source_file = .{ .path = "src/zrm.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zrmdir = b.addExecutable(.{
        .name = "zrmdir",
        .root_source_file = .{ .path = "src/zrmdir.zig" },
        .target = target,
        .optimize = optimize,
    });

    const exe_zcp = b.addExecutable(.{
        .name = "zcp",
        .root_source_file = .{ .path = "src/zcp.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zmv = b.addExecutable(.{
        .name = "zmv",
        .root_source_file = .{ .path = "src/zmv.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zsleep = b.addExecutable(.{
        .name = "zsleep",
        .root_source_file = .{ .path = "src/zsleep.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zcksum = b.addExecutable(.{
        .name = "zcksum",
        .root_source_file = .{ .path = "src/zcksum.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zwc = b.addExecutable(.{
        .name = "zwc",
        .root_source_file = .{ .path = "src/zwc.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_ztee = b.addExecutable(.{
        .name = "ztee",
        .root_source_file = .{ .path = "src/ztee.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zyes = b.addExecutable(.{
        .name = "zyes",
        .root_source_file = .{ .path = "src/zyes.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zcomm = b.addExecutable(.{
        .name = "zcomm",
        .root_source_file = .{ .path = "src/zcomm.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_ztrue = b.addExecutable(.{
        .name = "ztrue",
        .root_source_file = .{ .path = "src/ztrue.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zfalse = b.addExecutable(.{
        .name = "zfalse",
        .root_source_file = .{ .path = "src/zfalse.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zhostname = b.addExecutable(.{
        .name = "zhostname",
        .root_source_file = .{ .path = "src/zhostname.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zhostid = b.addExecutable(.{
        .name = "zhostid",
        .root_source_file = .{ .path = "src/zhostid.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zseq = b.addExecutable(.{
        .name = "zseq",
        .root_source_file = .{ .path = "src/zseq.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zbasename = b.addExecutable(.{
        .name = "zbasename",
        .root_source_file = .{ .path = "src/zbasename.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zbase64 = b.addExecutable(.{
        .name = "zbase64",
        .root_source_file = .{ .path = "src/zbase64.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zpwd = b.addExecutable(.{
        .name = "zpwd",
        .root_source_file = .{ .path = "src/zpwd.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe_zfold = b.addExecutable(.{
        .name = "zfold",
        .root_source_file = .{ .path = "src/zfold.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    const exe__working = b.addExecutable(.{
        .name = "_working",
        .root_source_file = .{ .path = "src/_working.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    // const exe__argparse = b.addExecutable(.{
    //     .name = "_argparse",
    //     .root_source_file = .{ .path = "src/_argparse.zig" },
    //     .target = target,
    //     .optimize = optimize,
    //     .single_threaded = single_threaded,
    // });
    // b.installArtifact(exe__argparse);

    const exe_argparse = b.addExecutable(.{
        .name = "argparse",
        .root_source_file = .{ .path = "src/argparse.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    // const exe_zwget = b.addExecutable(.{
    //     .name = "zwget",
    //     .root_source_file = .{ .path = "src/zwget.zig" },
    //     .target = target,
    //     .optimize = optimize,
    //     .single_threaded = single_threaded,
    // });
    // b.installArtifact(exe_zwget);

    //
    //
    //

    const exe_test = b.addExecutable(.{
        .name = "test",
        .root_source_file = .{ .path = "src/test.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });

    exe.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zecho.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zhead.root_module.addImport("zargh", zargh.module("zargh"));
    exe_ztail.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zcat.root_module.addImport("zargh", zargh.module("zargh"));
    exe_ztouch.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zmkdir.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zrm.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zrmdir.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zcp.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zmv.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zsleep.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zcksum.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zwc.root_module.addImport("zargh", zargh.module("zargh"));
    exe_ztee.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zyes.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zcomm.root_module.addImport("zargh", zargh.module("zargh"));
    exe_ztrue.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zfalse.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zhostname.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zhostid.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zseq.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zbasename.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zbase64.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zpwd.root_module.addImport("zargh", zargh.module("zargh"));
    exe_zfold.root_module.addImport("zargh", zargh.module("zargh"));
    exe__working.root_module.addImport("zargh", zargh.module("zargh"));
    exe_argparse.root_module.addImport("zargh", zargh.module("zargh"));
    exe_test.root_module.addImport("zargh", zargh.module("zargh"));

    b.installArtifact(exe);
    b.installArtifact(exe_zecho);
    b.installArtifact(exe_zhead);
    b.installArtifact(exe_ztail);
    b.installArtifact(exe_zcat);
    b.installArtifact(exe_ztouch);
    b.installArtifact(exe_zmkdir);
    b.installArtifact(exe_zrm);
    b.installArtifact(exe_zrmdir);
    b.installArtifact(exe_zcp);
    b.installArtifact(exe_zmv);
    b.installArtifact(exe_zsleep);
    b.installArtifact(exe_zcksum);
    b.installArtifact(exe_zwc);
    b.installArtifact(exe_ztee);
    b.installArtifact(exe_zyes);
    b.installArtifact(exe_zcomm);
    b.installArtifact(exe_ztrue);
    b.installArtifact(exe_zfalse);
    b.installArtifact(exe_zhostname);
    b.installArtifact(exe_zhostid);
    b.installArtifact(exe_zseq);
    b.installArtifact(exe_zbasename);
    b.installArtifact(exe_zbase64);
    b.installArtifact(exe_zpwd);
    b.installArtifact(exe_zfold);
    b.installArtifact(exe__working);
    b.installArtifact(exe_argparse);
    b.installArtifact(exe_test);

    // This *creates* a RunStep in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
