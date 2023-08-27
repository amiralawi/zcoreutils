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

    var single_threaded = builtin.single_threaded;
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
    b.installArtifact(exe);


    // additional executables
    const exe_zecho = b.addExecutable(.{
        .name = "zecho",
        .root_source_file = .{ .path = "src/zecho.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_zecho);


    const exe_zhead = b.addExecutable(.{
        .name = "zhead",
        .root_source_file = .{ .path = "src/zhead.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_zhead);

    const exe_ztail = b.addExecutable(.{
        .name = "ztail",
        .root_source_file = .{ .path = "src/ztail.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_ztail);

    const exe_zcat = b.addExecutable(.{
        .name = "zcat",
        .root_source_file = .{ .path = "src/zcat.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_zcat);


    const exe_ztouch = b.addExecutable(.{
        .name = "ztouch",
        .root_source_file = .{ .path = "src/ztouch.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_ztouch);

    const exe_zmkdir = b.addExecutable(.{
        .name = "zmkdir",
        .root_source_file = .{ .path = "src/zmkdir.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_zmkdir);


    const exe_zrm = b.addExecutable(.{
        .name = "zrm",
        .root_source_file = .{ .path = "src/zrm.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_zrm);

    const exe_zrmdir = b.addExecutable(.{
        .name = "zrmdir",
        .root_source_file = .{ .path = "src/zrmdir.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe_zrmdir);

    const exe_zcp = b.addExecutable(.{
        .name = "zcp",
        .root_source_file = .{ .path = "src/zcp.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_zcp);


    const exe_zmv = b.addExecutable(.{
        .name = "zmv",
        .root_source_file = .{ .path = "src/zmv.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_zmv);

    const exe_zsleep = b.addExecutable(.{
        .name = "zsleep",
        .root_source_file = .{ .path = "src/zsleep.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_zsleep);

    const exe_zcksum = b.addExecutable(.{
        .name = "zcksum",
        .root_source_file = .{ .path = "src/zcksum.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_zcksum);
    
    const exe_zwc = b.addExecutable(.{
        .name = "zwc",
        .root_source_file = .{ .path = "src/zwc.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_zwc);

    const exe_ztee = b.addExecutable(.{
        .name = "ztee",
        .root_source_file = .{ .path = "src/ztee.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_ztee);

    const exe_zyes = b.addExecutable(.{
        .name = "zyes",
        .root_source_file = .{ .path = "src/zyes.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_zyes);
    

    const exe_zcomm = b.addExecutable(.{
        .name = "zcomm",
        .root_source_file = .{ .path = "src/zcomm.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_zcomm);

    const exe_ztrue = b.addExecutable(.{
        .name = "ztrue",
        .root_source_file = .{ .path = "src/ztrue.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_ztrue);

    const exe_zfalse = b.addExecutable(.{
        .name = "zfalse",
        .root_source_file = .{ .path = "src/zfalse.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_zfalse);

    const exe_zhostname = b.addExecutable(.{
        .name = "zhostname",
        .root_source_file = .{ .path = "src/zhostname.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_zhostname);

    const exe_zhostid = b.addExecutable(.{
        .name = "zhostid",
        .root_source_file = .{ .path = "src/zhostid.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_zhostid);
    
    const exe_zseq = b.addExecutable(.{
        .name = "zseq",
        .root_source_file = .{ .path = "src/zseq.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    b.installArtifact(exe_zseq);


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
