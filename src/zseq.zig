// TODO - negative numbers
// TODO - NaN input errors
// TODO - Integer overflows

const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");
const za = @import("zargh");

const ftype = f64;
const itype = i64;
//const islow = i128;

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;

const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

const argContext = struct {
    const Self = @This();
    const base_exe_name = "zseq";

    exe_name: []const u8 = Self.base_exe_name,

    optFormat: za.Option = .{
        .short = 'f',
        .long = "format",
        .help = "use printf style floating-point format ARG",
        .action = za.Option.Actions.flagTrue,
        .argument = .required,
    },
    optSeparator: za.Option = .{
        .short = 's',
        .long = "separator",
        .help = "use ARG to separate numbers (default: \\n)",
        .argument = .required,
        .value = "\n",
    },
    optEqualWidth: za.Option = .{
        .short = 'w',
        .long = "equal-width",
        .help = "equalize width by padding with leading zeroes",
        .action = za.Option.Actions.flagTrue,
    },
    optHelp: za.Option = .{
        .long = "help",
        .help = "display this help and exit",
        .action = dispUsage,
    },
    optVersion: za.Option = .{
        .long = "version",
        .help = "output version information and exit",
        .action = dispVersion,
    },

    pub fn dispUsage(ctx: *anyopaque, opt: *za.Option) void {
        _ = opt;
        const c: *@This() = @alignCast(@ptrCast(ctx));
        stdout.print(
            \\Usage: {0s} [OPTION]... LAST
            \\  or:  {0s} [OPTION]... FIRST LAST
            \\  or:  {0s} [OPTION]... FIRST INCREMENT LAST
            \\Print numbers from FIRST to LAST, in steps of INCREMENT.
            \\
            \\Mandatory arguments to long options are mandatory for short options too.
            \\
        , .{c.exe_name}) catch {};
        stdout.print("{s}\r\n", .{za.Parser(Self).helpstr}) catch {};
        stdout.print(
            \\If FIRST or INCREMENT is omitted, it defaults to 1.  That is, an
            \\omitted INCREMENT defaults to 1 even when LAST is smaller than FIRST.
            \\The sequence of numbers ends when the sum of the current number and
            \\INCREMENT would become greater than LAST.
            \\FIRST, INCREMENT, and LAST are interpreted as floating point values.
            \\INCREMENT is usually positive if FIRST is smaller than LAST, and
            \\INCREMENT is usually negative if FIRST is greater than LAST.
            \\INCREMENT must not be 0; none of FIRST, INCREMENT and LAST may be NaN.
            \\FORMAT must be suitable for printing one argument of type 'double';
            \\it defaults to %.PRECf if FIRST, INCREMENT, and LAST are all fixed point
            \\decimal numbers with maximum precision PREC, and to %g otherwise.
            \\
        , .{}) catch {};

        c.optHelp.flag = true;
    }
    pub fn dispVersion(ctx: *anyopaque, opt: *za.Option) void {
        _ = opt;
        const c: *@This() = @alignCast(@ptrCast(ctx));
        stdout.print("version=xxx\r\n", .{}) catch {};
        c.optVersion.flag = true;
    }
};

const NumberTypeTag = enum {
    float,
    int,
};
const Number = union(NumberTypeTag) {
    float: ftype,
    int: itype,
};

fn parseNum(str: []const u8) !Number {
    // var n: Number = undefined;

    const i: ?itype = std.fmt.parseInt(itype, str, 0) catch null;
    if (i) |v| {
        return Number{ .int = v };
    }

    const f = try std.fmt.parseFloat(ftype, str);
    if (f != std.math.inf(ftype) and f == @round(f)) {
        return Number{ .int = @intFromFloat(f) };
    }
    return Number{ .float = f };

    // return n;
}

fn getPrecision(str: []const u8) usize {
    const idx_dot = std.mem.indexOf(u8, str, ".");
    var precision: usize = 0;
    if (idx_dot) |i| {
        for (str[i..], 0..) |c, x| {
            if (std.ascii.isDigit(c) and c != '0') {
                precision = x;
            }
        }
    }
    return precision;
}

pub fn main() !u8 {
    stdout = std.io.getStdOut().writer();
    stderr = std.io.getStdErr().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();
    var args = try za.getArgs(heapalloc);

    var ctx = argContext{};
    var parser = za.Parser(argContext).init(&ctx);
    ctx.exe_name = args.items[0];

    var npositional: usize = 0;
    for (args.items[1..]) |arg| {
        if (parser.parse(arg)) |isValidOpt| {
            if (!isValidOpt) {
                args.items[npositional] = arg;
                npositional += 1;
            }
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

        if (ctx.optHelp.flag or ctx.optVersion.flag) {
            return EXIT_SUCCESS;
        }
    }

    const unprocessed_args = args.items[0..npositional];

    var beg_raw: []const u8 = undefined;
    var inc_raw: []const u8 = undefined;
    var end_raw: []const u8 = undefined;

    switch (unprocessed_args.len) {
        0 => {
            try stderr.print("{s}: missing operand\n", .{ctx.exe_name});
            try stderr.print("Try '{s} --help' for more information.\n", .{ctx.exe_name});
            return EXIT_FAILURE;
        },
        1 => {
            beg_raw = "1";
            inc_raw = "1";
            end_raw = unprocessed_args[0];
        },
        2 => {
            beg_raw = unprocessed_args[0];
            inc_raw = "1";
            end_raw = unprocessed_args[1];
        },
        3 => {
            beg_raw = unprocessed_args[0];
            inc_raw = unprocessed_args[1];
            end_raw = unprocessed_args[2];
        },
        else => {
            try stderr.print("{s}: extra operand '{s}'\n", .{ ctx.exe_name, unprocessed_args[3] });
            try stderr.print("Try '{s} --help' for more information.\n", .{ctx.exe_name});
            return EXIT_FAILURE;
        },
    }

    // if beg is float -> float mode
    // if inc is float -> float mode
    // if only end is float, it can be safely turned into int
    const beg = try parseNum(beg_raw);
    const inc = try parseNum(inc_raw);
    const end = try parseNum(end_raw);

    if ((inc == NumberTypeTag.int and inc.int == 0) or
        (inc == NumberTypeTag.float and inc.float == 0))
    {
        try stderr.print("{s}: invalid Zero incrment value: '{s}'\n", .{ ctx.exe_name, inc_raw });
        try stderr.print("Try '{s} --help' for more information.\n", .{ctx.exe_name});
        return EXIT_FAILURE;
    }

    if (beg == NumberTypeTag.float or inc == NumberTypeTag.float) {
        // float mode
        std.debug.print("FLOAT MODE!\n", .{});

        const beg_f: ftype = if (beg == NumberTypeTag.float) beg.float else @floatFromInt(beg.int);
        const inc_f: ftype = if (inc == NumberTypeTag.float) inc.float else @floatFromInt(inc.int);
        const end_f: ftype = if (end == NumberTypeTag.float) end.float else @floatFromInt(end.int);

        const precision = getPrecision(inc_raw);
        std.debug.print("PRECISION={d}\n", .{precision});

        var x = beg_f;
        while (x <= end_f) {
            //std.fmt.format_float.formatFloat(x, .{ .precision = precision }, stdout);
            try stdout.print("{[x]d:.[precision]}{[s]s}", .{
                .x = x,
                .precision = precision,
                .s = ctx.optSeparator.value.?,
            });
            //try stdout.print("π = {[x]d:.[precision]}\n", .{ .x = std.math.pi, .precision = 2 });

            x += inc_f;
        }

        return EXIT_SUCCESS;
    }

    // int mode
    const inc_i = inc.int;
    var x = beg.int;

    if (end == NumberTypeTag.float and end.float == std.math.inf(ftype)) {
        while (true) {
            x += inc_i;
            try stdout.print("{d}{s}", .{ x, ctx.optSeparator.value.? });
        }
    }

    const end_i: itype = if (end == NumberTypeTag.float) @intFromFloat(end.float) else end.int;
    while (x <= end_i) {
        try stdout.print("{d}{s}", .{ x, ctx.optSeparator.value.? });
        x += inc_i;
    }

    return EXIT_SUCCESS;
}
