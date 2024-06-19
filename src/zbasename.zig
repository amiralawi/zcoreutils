const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");
const za = @import("zargh");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;

const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

pub const zbasenameContext = struct {
    const Self = @This();
    const base_exe_name = "zbasename";

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
    multiple: za.Option = .{
        .short = 'a',
        .long = "multiple",
        .help = "support multiple arguments and treat each as a NAME",
        .action = za.Option.Actions.flagTrue,
    },
    suffix: za.Option = .{
        .short = 's',
        .long = "suffix",
        .help = "remove a trailing SUFFIX; implies -a",
        .action = setSuffix,
        .argument = .required,
        .value = "",
    },
    zero: za.Option = .{
        .short = 'z',
        .long = "zero",
        .help = "end each output line with NUL, not newline",
        .action = za.Option.Actions.flagTrue,
    },

    pub fn setSuffix(ctx: *anyopaque, opt: *za.Option) void {
        _ = opt;
        var c: *@This() = @alignCast(@ptrCast(ctx));
        c.suffix.flag = true;
        c.multiple.flag = true;
    }

    pub fn dispUsage(ctx: *anyopaque, opt: *za.Option) void {
        _ = opt;
        const c: *@This() = @alignCast(@ptrCast(ctx));
        stdout.print(
            \\Usage: {0s} NAME [SUFFIX]
            \\  or:  {0s} OPTION... NAME...
            \\Print NAME with any leading directory components removed.
            \\If specified, also remove a trailing SUFFIX.
            \\
            \\Mandatory arguments to long options are mandatory for short options too.
            \\
        , .{c.exe_name}) catch {};
        stdout.print("{s}\r\n", .{za.Parser(Self).helpstr}) catch {};
        stdout.print(
            \\Examples:
            \\  {0s} /usr/bin/sort          -> "sort"
            \\  {0s} include/stdio.h .h     -> "stdio"
            \\  {0s} -s .h include/stdio.h  -> "stdio"
            \\  {0s} -a any/str1 any/str2   -> "str1" followed by "str2"
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
    stderr = std.io.getStdErr().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();

    var args = try za.getArgs(heapalloc);

    var ctx = zbasenameContext{};
    var parser = za.Parser(zbasenameContext).init(&ctx);
    ctx.exe_name = args.items[0];

    var nfilenames: usize = 0;
    for (args.items[1..]) |arg| {
        // Move anything that isn't a valid option to the beginning of args - take the bottom
        // slice for use as filenames later
        if (parser.parse(arg)) |isValidOpt| {
            if (!isValidOpt) {
                // end options parsing when first non-option argument is detected
                parser.ignore_options = true;
                args.items[nfilenames] = arg;
                nfilenames += 1;
            }
        } else |err| switch (err) {
            error.InvalidLongOption => {
                try stderr.print("{s}: invalid long option '{s}'\r\n", .{ ctx.exe_name, arg });
                return EXIT_FAILURE;
            },
            error.InvalidShortOption => {
                try stderr.print("{s}: invalid short option '{s}'\r\n", .{ ctx.exe_name, arg });
                return EXIT_FAILURE;
            },
            error.UnexpectedArgument => {
                try stderr.print("{s}: option '{s}' has unexpected argument\r\n", .{ ctx.exe_name, arg });
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

    var filenames = args.items[0..nfilenames];

    if (filenames.len == 0) {
        try stdout.print("{s}: missing operand\r\n", .{ctx.exe_name});
        try stdout.print("Try '{s} --help' for more information.\r\n", .{ctx.exe_name});
        return EXIT_FAILURE;
    }

    if (!ctx.multiple.flag) switch (nfilenames) {
        1 => {},
        2 => {
            ctx.suffix.value = filenames[1];
            filenames = filenames[0..1];
        },
        else => {
            try stdout.print("{s}: extra operand '{s}'\r\n", .{ ctx.exe_name, filenames[2] });
            try stdout.print("Try '{s} --help' for more information.\r\n", .{ctx.exe_name});
            return EXIT_FAILURE;
        },
    };

    const separator: u8 = if (ctx.zero.flag) '\x00' else '\n';

    for (filenames) |filename| {
        var f: []const u8 = std.fs.path.basename(filename);
        if (std.mem.endsWith(u8, filename, ctx.suffix.value.?)) {
            f = f[0 .. f.len - ctx.suffix.value.?.len];
        }
        try stdout.print("{s}{c}", .{ f, separator });
    }

    return EXIT_SUCCESS;
}
