const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");
const za = @import("zargh");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;

const base_exe_name = "zyes";
const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

const zyesContext = struct {
    const Self = @This();
    const base_exe_name = "zyes";

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
            \\Usage: {0s} [STRING]...
            \\  or:  {0s} OPTION
            \\Repeatedly output a line with all specified STRING(s), or 'y'.
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

    var ctx = zyesContext{};
    var parser = za.Parser(zyesContext).init(&ctx);
    ctx.exe_name = args.items[0];

    var nprintargs: usize = 0;
    for (args.items[1..]) |arg| {
        // Move anything that isn't a valid option to the beginning of args - take the bottom
        // slice for use as filenames later
        if (parser.parse(arg)) |isValidOpt| {
            if (!isValidOpt) {
                args.items[nprintargs] = arg;
                nprintargs += 1;
            }
        } else |err| switch (err) {
            error.InvalidLongOption => {
                try stderr.print("{s}: invalid long option '{s}'\r\n", .{ ctx.exe_name, arg });
                try stderr.print("Try '{s} --help' for more information.\r\n", .{ctx.exe_name});
                return EXIT_FAILURE;
            },
            error.InvalidShortOption => {
                try stderr.print("{s}: invalid short option '{s}'\r\n", .{ ctx.exe_name, arg });
                try stderr.print("Try '{s} --help' for more information.\r\n", .{ctx.exe_name});
                return EXIT_FAILURE;
            },
            error.UnexpectedArgument => {
                try stderr.print("{s}: option '{s}' has unexpected argument\r\n", .{ ctx.exe_name, arg });
                try stderr.print("Try '{s} --help' for more information.\r\n", .{ctx.exe_name});
                return EXIT_FAILURE;
            },
        }

        // do this in the loop to allow early exit
        if (ctx.help.flag) {
            return EXIT_SUCCESS;
        }
        if (ctx.version.flag) {
            return EXIT_SUCCESS;
        }
    }
    var printargs = args.items[0..nprintargs];
    if (printargs.len == 0) {
        while (true) {
            try stdout.print("y\n", .{});
        }
    } else if (printargs.len == 1) {
        while (true) {
            try stdout.print("{s}\n", .{printargs[0]});
        }
    } else {
        while (true) {
            try stdout.print("{s}", .{printargs[0]});
            for (printargs[1..]) |pa| {
                try stdout.print(" {s}", .{pa});
            }
            try stdout.print("\n", .{});
        }
    }

    return EXIT_SUCCESS;
}
