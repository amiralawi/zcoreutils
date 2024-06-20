const std = @import("std");
const za = @import("zargh");

const library = @import("./zcorecommon/library.zig");
const cli = @import("./zcorecommon/cli.zig");
const util = @import("./zcorecommon/util.zig");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;

const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

const zsleepContext = struct {
    const Self = @This();
    const base_exe_name = "zsleep";

    exe_name: []const u8 = Self.base_exe_name,

    help: za.Option = .{
        .long = "help",
        .help = "display this help and exit",
        .action = dispUsage,
    },
    version: za.Option = .{
        .long = "version",
        .help = "output version information and exit",
        .action = dispVersion,
    },

    pub fn dispUsage(ctx: *anyopaque, opt: *za.Option) void {
        _ = opt;
        const c: *@This() = @alignCast(@ptrCast(ctx));
        stdout.print(
            \\Usage: {s} NUMBER[SUFFIX]...\n
            \\  or:  sleep OPTION
            \\Pause for NUMBER seconds.  Optional SUFFIX may be one of:
            \\  's' for seconds (the default)
            \\  'm' for minutes
            \\  'h' for hours
            \\  'd' for days
            \\NUMBER may be any positive integer or floating-point number. Given
            \\two or more arguments, pause for the amount of time specified by
            \\the sum of their values.
            \\
            \\
        , .{c.exe_name}) catch {};
        stdout.print("{s}\r\n", .{za.Parser(Self).helpstr}) catch {};

        c.help.flag = true;
    }
    pub fn dispVersion(ctx: *anyopaque, opt: *za.Option) void {
        _ = opt;
        const c: *@This() = @alignCast(@ptrCast(ctx));
        stdout.print("version=xxx\r\n", .{}) catch {};
        c.version.flag = true;
    }
};

pub fn main() !u8 {
    stdout = std.io.getStdOut().writer();
    stderr = std.io.getStdErr().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();

    var args = try za.getArgs(heapalloc);

    var ctx = zsleepContext{};
    var parser = za.Parser(zsleepContext).init(&ctx);
    ctx.exe_name = args.items[0];

    if (args.items.len == 1) {
        // no arguments supplied
        try stdout.print("{s}: missing operand\n", .{ctx.exe_name});
        try stdout.print("Try '{s} --help' for more information.\n", .{ctx.exe_name});
        return EXIT_FAILURE;
    }

    var dt_accum: f64 = 0;
    var ntimeargs: usize = 0;
    for (args.items[1..]) |arg| {
        if (parser.parse(arg)) |isValidOpt| {
            if (isValidOpt) {
                // --help or --version was called
                return EXIT_SUCCESS;
            }
            args.items[ntimeargs] = arg;
            ntimeargs += 1;
        } else |err| switch (err) {
            error.InvalidLongOption => {
                try stderr.print("{s}: invalid long option '{s}'\r\n", .{ ctx.exe_name, arg });
                try stderr.print("Try '{s} --help' for more information.\n", .{ctx.exe_name});
                return EXIT_FAILURE;
            },
            error.InvalidShortOption => {
                try stderr.print("{s}: invalid short option '{s}'\r\n", .{ ctx.exe_name, arg });
                try stderr.print("Try '{s} --help' for more information.\n", .{ctx.exe_name});
                return EXIT_FAILURE;
            },
            error.UnexpectedArgument => {
                try stderr.print("{s}: option '{s}' has unexpected argument\r\n", .{ ctx.exe_name, arg });
                try stderr.print("Try '{s} --help' for more information.\n", .{ctx.exe_name});
                return EXIT_FAILURE;
            },
        }
    }

    for (args.items[0..ntimeargs]) |dt| {
        if (dt.len == 0) {
            // not sure if this condition is possible, guard against just in case
            continue;
        }

        var dt_clean: []const u8 = undefined;
        var mult: f64 = undefined;
        switch (dt[dt.len - 1]) {
            'm' => {
                dt_clean = dt[0 .. dt.len - 1];
                mult = 60.0;
            },
            'h' => {
                dt_clean = dt[0 .. dt.len - 1];
                mult = 60.0 * 60.0;
            },
            'd' => {
                dt_clean = dt[0 .. dt.len - 1];
                mult = 60.0 * 60.0 * 24.0;
            },
            's' => {
                dt_clean = dt[0 .. dt.len - 1];
                mult = 1.0;
            },
            else => {
                dt_clean = dt;
                mult = 1.0;
            },
        }

        const dt_val = std.fmt.parseFloat(f64, dt_clean) catch {
            try stderr.print("{s}: invalid time interval '{s}'\n", .{ ctx.exe_name, dt });
            try stderr.print("Try '{s} --help' for more information.\n", .{ctx.exe_name});
            return EXIT_FAILURE;
        };
        if (dt_val < 0.0) {
            try stderr.print("{s}: invalid time interval '{s}'\n", .{ ctx.exe_name, dt });
            try stderr.print("Try '{s} --help' for more information.\n", .{ctx.exe_name});
            return EXIT_FAILURE;
        }
        dt_accum += mult * dt_val;
    }

    const ns_sleep: u64 = @intFromFloat(dt_accum * 1000000000.0);
    std.time.sleep(ns_sleep);

    return EXIT_SUCCESS;
}
