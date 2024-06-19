const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

const assert = std.debug.assert;
const expect = std.testing.expect;

const za = @import("zargh.zig");

pub const EchoDescriptor = struct {
    const Self = @This();

    newline: za.Option = .{ .short = 'n', .help = "do not append a newline" },
    process_escapes: za.Option = .{ .short = 'e', .help = "enable interpretation of the following backslash escapes" },
    process_escapes_inv: za.Option = .{ .short = 'E', .help = "explicitly suppress interpretation of backslash escapes", .action = flagE },

    // TODO - remove, for testing only
    fizz: za.Option = .{ .short = 'f', .help = "print a fizz", .action = fizz },
    buzz: za.Option = .{ .long = "buzz", .help = "print a buzz", .action = buzz },
    help: za.Option = .{ .short = 'h', .long = "help", .help = "print this menu and exit", .action = usage },
    anon: za.Option = .{ .short = 'q', .long = "anon", .help = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum." },
    //help: za.Option = .{ .short = 'h', .help = "print this menu and exit", .action = za.Parser(EchoDescriptor).printUsage },

    pub fn fizz(context: *anyopaque) void {
        _ = context; // autofix
        std.debug.print("fizz!\r\n", .{});
    }
    pub fn buzz(context: *anyopaque) void {
        _ = context; // autofix
        std.debug.print("buzz!\r\n", .{});
    }
    pub fn flagE(context: *anyopaque) void {
        var self: *Self = @ptrCast(@alignCast(context));
        //var self: *Self = @ptrCast(context);

        self.process_escapes.flag = false;
    }
    pub fn usage(context: *anyopaque) void {
        _ = context; // autofix
        const pre =
            \\echo: echo [-neE] [arg ...]
            \\
            \\Write arguments to the standard output.
            \\
            \\Display the ARGs, separated by a single space character and followed by a
            \\newline, on the standard output.
            \\
            \\Options:
        ;
        const post =
            \\`echo' interprets the following backslash-escaped characters:
            \\    \a         alert (bell)
            \\    \b         backspace
            \\    \c         suppress further output
            \\    \e         escape character
            \\    \E         escape character
            \\    \f         form feed
            \\    \n         new line
            \\    \r         carriage return
            \\    \t         horizontal tab
            \\    \v         vertical tab
            \\    \\         backslash
            \\    \0nnn      the character whose ASCII code is NNN (octal).  NNN can be
            \\               0 to 3 octal digits
            \\    \xHH       the eight-bit character whose value is HH (hexadecimal).  HH
            \\               can be one or two hex digits
            \\    \uHHHH     the Unicode character whose value is the hexadecimal value HHHH.
            \\               HHHH can be one to four hex digits.
            \\    \UHHHHHHHH the Unicode character whose value is the hexadecimal value
            \\               HHHHHHHH. HHHHHHHH can be one to eight hex digits.
            \\
            \\  Exit Status:
            \\  Returns success unless a write error occurs.
        ;
        std.debug.print("{s}\r\n", .{pre});
        std.debug.print("{s}\r\n", .{za.Parser(Self).helpstr});
        std.debug.print("{s}\r\n", .{post});
    }
};

const ParseContext = struct {
    const Self = @This();
    a: za.Option = .{ .short = 'a', .help = "short option a with action", .action = Self.testAction },
    b: za.Option = .{ .short = 'b', .help = "short option b" },
    c: za.Option = .{ .long = "c", .help = "long option c" },

    d: za.Option = .{ .short = 'd', .argument = .optional, .help = "short option d, argument=optional" },
    e: za.Option = .{ .short = 'e', .argument = .required, .help = "short option e, argument=required" },
    f: za.Option = .{ .short = 'f', .long = "flongopt", .help = "short option f, long option flongopt" },
    g: za.Option = .{ .short = 'g', .argument = .required, .help = "short option g, argument=required" },
    h: za.Option = .{ .long = "hlongopt", .argument = .required, .help = "long option hlongopt, argument=required" },
    i: za.Option = .{ .short = 'i', .argument = .optional, .help = "short option i, argument=optional" },
    j: za.Option = .{ .long = "jlongopt", .argument = .optional, .help = "long option jlongopt, argument=optional" },
    k: za.Option = .{ .short = 'k', .long = "loremipsum", .argument = .optional, .help = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum." },
    l: za.Option = .{ .short = 'l', .help = "dangling short option j" },
    testvar: bool = false,

    pub fn testAction(context: *anyopaque) void {
        var self: *Self = @ptrCast(@alignCast(context));

        self.testvar = true;
    }
};
pub fn main() !void {
    // implements zecho as testbed for _argparse

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();

    var args = std.ArrayList([]const u8).init(heapalloc);
    const filenames = std.ArrayList([]const u8).init(heapalloc);
    _ = filenames; // autofix
    try cli.args.appendToArrayList(&args, heapalloc);

    var desc = comptime EchoDescriptor{};

    var parser = za.Parser(EchoDescriptor).init(&desc);

    //std.debug.print("{s}\r\n", .{za.Parser(ParseContext).helpstr});

    // //
    // // beg
    // //
    // const helpstr_generated = za.Parser(ParseContext).helpstr;
    // const helpstr_expected: []const u8 =
    //     "  -a                      short option a with action\r\n" ++
    //     "  -b                      short option b\r\n" ++
    //     "      --c                 long option c\r\n" ++
    //     "  -d                      short option d, argument=optional\r\n" ++
    //     "  -e                      short option e, argument=required\r\n" ++
    //     "  -f, --flongopt          short option f, long option flongopt\r\n" ++
    //     "  -g                      short option g, argument=required\r\n" ++
    //     "      --hlongopt=ARG      long option hlongopt, argument=required\r\n" ++
    //     "  -i                      short option i, argument=optional\r\n" ++
    //     "      --jlongopt[=ARG]    long option jlongopt, argument=optional\r\n" ++
    //     "  -k, --loremipsum[=ARG]  Lorem ipsum dolor sit amet, consectetur adipiscing eli\r\n" ++
    //     "                          t, sed do eiusmod tempor incididunt ut labore et dolor\r\n" ++
    //     "                          e magna aliqua. Ut enim ad minim veniam, quis nostrud \r\n" ++
    //     "                          exercitation ullamco laboris nisi ut aliquip ex ea com\r\n" ++
    //     "                          modo consequat. Duis aute irure dolor in reprehenderit\r\n" ++
    //     "                           in voluptate velit esse cillum dolore eu fugiat nulla\r\n" ++
    //     "                           pariatur. Excepteur sint occaecat cupidatat non proid\r\n" ++
    //     "                          ent, sunt in culpa qui officia deserunt mollit anim id\r\n" ++
    //     "                           est laborum.\r\n" ++
    //     "  -l                      dangling short option j\r\n";
    // //_ = std.mem.eql(u8, helpstr_expected, &za.Parser(descriptor).helpstr);
    // std.debug.print("genlen={d} explen={d}\r\n", .{ helpstr_generated.len, helpstr_expected.len });
    // std.debug.print("mem.eql={}\r\n", .{std.mem.eql(u8, helpstr_expected, &za.Parser(ParseContext).helpstr)});
    // var nmatch: usize = 0;
    // for (0..helpstr_expected.len) |i| {
    //     const cg = helpstr_generated[i];
    //     const ce = helpstr_expected[i];
    //     const match = cg == ce;
    //     if (match) {
    //         nmatch += 1;
    //     }
    //     std.debug.print("{d} -> (", .{i});
    //     if (std.ascii.isPrint(cg)) {
    //         std.debug.print("'{c}'", .{cg});
    //     } else {
    //         std.debug.print("{d}", .{cg});
    //     }
    //     if (std.ascii.isPrint(ce)) {
    //         std.debug.print(", '{c}')", .{ce});
    //     } else {
    //         std.debug.print(", {d})", .{ce});
    //     }
    //     std.debug.print(" {}\r\n", .{match});
    // }
    // std.debug.print("nmatch={d}\r\n", .{nmatch});
    // //
    // // end
    // //

    for (args.items[1..]) |arg| {
        //std.debug.print("arg='{s}'\r\n", .{arg});

        if (parser.parse(arg)) |parseret| {
            _ = parseret; // autofix
            if (desc.help.flag) {
                return;
            }
            //std.debug.print("  ret='{}'\r\n", .{parseret});
        } else |err| {
            std.debug.print("  ->error arg='{s}' ({any})\r\n", .{ arg, err });
        }
    }

    std.debug.print("report:\r\n", .{});
    std.debug.print("    n={}\t#={d}\r\n", .{ desc.newline.flag, desc.newline.count });
    std.debug.print("    e={}\t#={d}\r\n", .{ desc.process_escapes.flag, desc.process_escapes.count });
    std.debug.print("    E={}\t#={d}\r\n", .{ desc.process_escapes_inv.flag, desc.process_escapes_inv.count });
}
