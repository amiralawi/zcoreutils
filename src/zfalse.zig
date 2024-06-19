const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");
const za = @import("zargh");

var stdout: std.fs.File.Writer = undefined;

const EXIT_FAILURE: u8 = 1;

const zfalseContext = struct {
    const Self = @This();
    const base_exe_name = "zfalse";

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
            \\Usage: {0s} [ignored command line arguments]
            \\  or:  {0s} OPTION
            \\Exit with a status code indicating failure.
            \\
        , .{c.exe_name}) catch {};
        stdout.print("{s}\r\n", .{za.Parser(Self).helpstr}) catch {};
        stdout.print(
            \\
            \\NOTE: your shell may have its own version of {s}, which usually supersedes
            \\the version described here.  Please refer to your shell's documentation
            \\for details about the options it supports.
            \\
        , .{c.exe_name}) catch {};

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
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();

    var args = try za.getArgs(heapalloc);

    var ctx = zfalseContext{};
    var parser = za.Parser(zfalseContext).init(&ctx);
    ctx.exe_name = args.items[0];

    for (args.items[1..]) |arg| {
        _ = parser.parse(arg) catch {};
        if (ctx.help.flag or ctx.version.flag) {
            return EXIT_FAILURE;
        }
    }

    return EXIT_FAILURE;
}
