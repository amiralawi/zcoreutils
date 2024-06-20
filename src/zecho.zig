const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");
const za = @import("zargh");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;

const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

const escape_state = enum {
    unescaped,
    escape_started,
    octal,
    hexadecimal,
    unicode_little,
    unicode_big,
};

pub fn print_octal_char() !void {
    var accum: u32 = 0;
    while (ebuffer.read()) |ch| {
        accum = 8 * accum + util.char.getOctalValue(ch);
    }
    const accum_trunc: u8 = @truncate(accum);
    try stdout.print("{c}", .{accum_trunc});
}

pub fn print_hex_char() !void {
    var accum: u32 = 0;
    while (ebuffer.read()) |ch| {
        accum = 16 * accum + util.char.getHexValue(ch);
    }
    const accum_trunc: u8 = @truncate(accum);
    try stdout.print("{c}", .{accum_trunc});
}

pub fn print_unicode_char() !void {
    // TODO
}

var e_state: escape_state = .unescaped;

var ebuffer_data: [16]u8 = undefined;
var ebuffer_fba = std.heap.FixedBufferAllocator.init(&ebuffer_data);
var ebuffer: std.RingBuffer = undefined;

var estack: [16]u8 = undefined;
var istack: usize = 0;
var suppress_flag = false;

pub fn process_char(ch: u8) !void {
    switch (e_state) {
        .unescaped => {
            if (ch == '\\') {
                e_state = .escape_started;
            } else {
                try stdout.print("{c}", .{ch});
            }
        },
        .escape_started => {
            switch (ch) {
                'a' => {
                    try stdout.print("{c}", .{0x07});
                    e_state = .unescaped;
                },
                'b' => {
                    try stdout.print("{c}", .{0x08});
                    e_state = .unescaped;
                },

                // TODO - not quite sure how to handle \e and \E characters - need to do more research
                //'e'  => { try stdout.print("\a", .{}); escape_stack_size = 0; },
                //'E'  => { try stdout.print("\a", .{}); escape_stack_size = 0; },

                'f' => {
                    try stdout.print("{c}", .{0xFF});
                    e_state = .unescaped;
                },
                'n' => {
                    try stdout.print("\n", .{});
                    e_state = .unescaped;
                },
                'r' => {
                    try stdout.print("\r", .{});
                    e_state = .unescaped;
                },
                't' => {
                    try stdout.print("\t", .{});
                    e_state = .unescaped;
                },
                'v' => {
                    try stdout.print("{c}", .{0x7C});
                    e_state = .unescaped;
                },
                '\\' => {
                    try stdout.print("{c}", .{'\\'});
                    e_state = .unescaped;
                },
                '0' => {
                    e_state = .octal;
                },
                'x' => {
                    e_state = .hexadecimal;
                },
                'u' => {
                    e_state = .unicode_little;
                },
                'U' => {
                    e_state = .unicode_big;
                },

                'c' => {
                    suppress_flag = true;
                    e_state = .unescaped;
                    return;
                },

                else => {
                    e_state = .unescaped;
                },
            }
        },
        .octal => {
            // octal \0nnn, n can be 0 to 3 octal digits
            if (!util.char.isOctal(ch)) {
                try print_octal_char();
                e_state = .unescaped;
                try process_char(ch);
            } else {
                try ebuffer.write(ch);
                if (ebuffer.len() == 3) {
                    try print_octal_char();
                    e_state = .unescaped;
                }
            }
        },
        .hexadecimal => {
            // hexadecimal \xHH, H can be 1 or 2 hex digits

            if (!std.ascii.isHex(ch)) {
                try print_hex_char();
                e_state = .unescaped;
                try process_char(ch);
            } else {
                try ebuffer.write(ch);
                if (ebuffer.len() == 2) {
                    try print_hex_char();
                    e_state = .unescaped;
                }
            }
        },
        .unicode_little => {
            // TODO - finish placeholder
            // unicode \uHHHH, H can be 1 to 4 hex digits
            e_state = .unescaped;
        },
        .unicode_big => {
            // TODO - finish placeholder
            // unicode \UHHHHHHHH, H can be 1 to 8 hex digits
            e_state = .unescaped;
        },
    }
}

pub fn print_dangling_escape_sequences() !void {
    switch (e_state) {
        .octal => {
            try print_octal_char();
        },
        .hexadecimal => {
            try print_hex_char();
        },
        .unicode_little, .unicode_big => {
            try print_unicode_char();
        },
        else => {},
    }
}

const zsleepContext = struct {
    const Self = @This();
    const base_exe_name = "zecho";

    exe_name: []const u8 = Self.base_exe_name,

    suppressNewline: za.Option = .{
        .short = 'n',
        .help = "do not output the trailing newline",
        .action = za.Option.Actions.flagTrue,
    },
    handleEscapes: za.Option = .{
        .short = 'e',
        .help = "enable interpretation of backslash escapes",
        .action = za.Option.Actions.flagTrue,
    },
    clearEscapes: za.Option = .{
        .short = 'E',
        .help = "disable interpretation of backslash escapes (default)",
        .action = clearHandleEscapes,
    },
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

    pub fn clearHandleEscapes(ctx: *anyopaque, opt: *za.Option) void {
        _ = opt;
        const c: *@This() = @alignCast(@ptrCast(ctx));
        c.handleEscapes.flag = false;
    }
    pub fn dispUsage(ctx: *anyopaque, opt: *za.Option) void {
        _ = opt;
        const c: *@This() = @alignCast(@ptrCast(ctx));
        stdout.print(
            \\Usage: {0s} [SHORT-OPTION]... [STRING]...
            \\  or:  {0s} LONG-OPTION
            \\Echo the STRING(s) to standard output.
            \\
        , .{c.exe_name}) catch {};

        stdout.print("{s}\r\n", .{za.Parser(Self).helpstr}) catch {};
        stdout.print(
            \\
            \\If -e is in effect, the following sequences are recognized:
            \\
            \\  \\\\      backslash
            \\  \\a      alert (BEL)
            \\  \\b      backspace
            \\  \\c      produce no further output
            \\  \\e      escape
            \\  \\f      form feed
            \\  \\n      new line
            \\  \\r      carriage return
            \\  \\t      horizontal tab
            \\  \\v      vertical tab
            \\  \\0NNN   byte with octal value NNN (1 to 3 digits)
            \\  \\xHH    byte with hexadecimal value HH (1 to 2 digits)
            \\
            \\NOTE: your shell may have its own version of {s}, which usually supersedes
            \\the version described here.  Please refer to your shell's documentation
            \\for details about the options it supports.
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

    const ebuff_alloc = ebuffer_fba.allocator();
    ebuffer = try std.RingBuffer.init(ebuff_alloc, 16);
    defer ebuffer.deinit(ebuff_alloc);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();

    var args = try za.getArgs(heapalloc);
    var ctx = zsleepContext{};
    var parser = za.Parser(zsleepContext).init(&ctx);
    ctx.exe_name = args.items[0];

    var n_printable: usize = 0;
    for (args.items[1..]) |arg| {
        if (parser.parse(arg)) |isValidOpt| {
            if (!isValidOpt) {
                args.items[n_printable] = arg;
                n_printable += 1;
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
    }

    const args_to_print = args.items[0..n_printable];

    // dumb path
    if (!ctx.handleEscapes.flag) {
        for (args_to_print, 1..) |arg, index| {
            const suffix = if (index == n_printable) "" else " ";
            try stdout.print("{s}{s}", .{ arg, suffix });
        }
        if (ctx.suppressNewline.flag == false) {
            try stdout.print("\n", .{});
        }
        return EXIT_SUCCESS;
    }

    // escape sequence path
    for (args_to_print, 1..) |arg, index| {
        const suffix = if (index == n_printable) "" else " ";

        for (arg) |ch| {
            try process_char(ch);
        }

        try print_dangling_escape_sequences();

        try stdout.print("{s}", .{suffix});
    }

    if (ctx.suppressNewline.flag == false) {
        try stdout.print("\n", .{});
    }

    return EXIT_SUCCESS;
}
