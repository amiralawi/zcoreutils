const std = @import("std");
const za = @import("zargh.zig");

const expect = std.testing.expect;
const expectError = std.testing.expectError;

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

test "helpstr constant" {
    const helpstr_gen = za.Parser(ParseContext).helpstr;
    const helpstr_expected: []const u8 =
        "  -a                      short option a with action\r\n" ++
        "  -b                      short option b\r\n" ++
        "      --c                 long option c\r\n" ++
        "  -d                      short option d, argument=optional\r\n" ++
        "  -e                      short option e, argument=required\r\n" ++
        "  -f, --flongopt          short option f, long option flongopt\r\n" ++
        "  -g                      short option g, argument=required\r\n" ++
        "      --hlongopt=ARG      long option hlongopt, argument=required\r\n" ++
        "  -i                      short option i, argument=optional\r\n" ++
        "      --jlongopt[=ARG]    long option jlongopt, argument=optional\r\n" ++
        "  -k, --loremipsum[=ARG]  Lorem ipsum dolor sit amet, consectetur adipiscing eli\r\n" ++
        "                          t, sed do eiusmod tempor incididunt ut labore et dolor\r\n" ++
        "                          e magna aliqua. Ut enim ad minim veniam, quis nostrud \r\n" ++
        "                          exercitation ullamco laboris nisi ut aliquip ex ea com\r\n" ++
        "                          modo consequat. Duis aute irure dolor in reprehenderit\r\n" ++
        "                           in voluptate velit esse cillum dolore eu fugiat nulla\r\n" ++
        "                           pariatur. Excepteur sint occaecat cupidatat non proid\r\n" ++
        "                          ent, sunt in culpa qui officia deserunt mollit anim id\r\n" ++
        "                           est laborum.\r\n" ++
        "  -l                      dangling short option j\r\n";

    const match = std.mem.eql(u8, helpstr_expected, &helpstr_gen);
    try std.testing.expect(match);
}

test "default values" {
    const ctx: ParseContext = .{};
    try expect(ctx.testvar == false);
    try expect(ctx.a.flag == false);
    try expect(ctx.b.flag == false);
    try expect(ctx.c.flag == false);

    try expect(ctx.c.count == 0);
    try expect(ctx.c.count == 0);
    try expect(ctx.c.count == 0);

    try expect(ctx.c.value == null);
    try expect(ctx.c.value == null);
    try expect(ctx.c.value == null);
}

test "parsing non-options" {
    var ctx: ParseContext = .{};
    var parser = za.Parser(ParseContext).init(&ctx);

    try expect(!try parser.parse("not an option"));
}

test "parsing invalid-options" {
    var ctx: ParseContext = .{};
    var parser = za.Parser(ParseContext).init(&ctx);

    // try expect(!try parser.parse("not an option"));
    try expectError(za.ParseError.InvalidLongOption, parser.parse("--notanoption"));
    try expectError(za.ParseError.InvalidShortOption, parser.parse("-z"));
}

test "parsing simple options" {
    var ctx: ParseContext = .{};
    var parser = za.Parser(ParseContext).init(&ctx);

    const valid_options = [_][]const u8{ "-a", "-b", "-b", "--c", "--c", "--c" };
    for (valid_options) |arg| {
        try expect(try parser.parse(arg));
    }

    try expect(ctx.testvar);

    try expect(ctx.a.flag);
    try expect(ctx.b.flag);
    try expect(ctx.c.flag);

    try expect(ctx.a.count == 1);
    try expect(ctx.b.count == 2);
    try expect(ctx.c.count == 3);
}

test "parsing argument optional/required options" {
    var ctx: ParseContext = .{};
    var parser = za.Parser(ParseContext).init(&ctx);

    // optional
    _ = try parser.parse("-d");
    try expect(ctx.d.value == null);
    try expect(parser.option_expecting_argument == null);

    _ = try parser.parse("-dabc");
    try expect(std.mem.eql(u8, ctx.d.value.?, "abc"));

    _ = try parser.parse("-d");
    try expect(ctx.d.value == null);

    // required
    _ = try parser.parse("-e");
    try expect(ctx.e.value == null);
    try expect(parser.option_expecting_argument.? == &ctx.e);

    _ = try parser.parse("def");
    try expect(parser.option_expecting_argument == null);
    try expect(std.mem.eql(u8, ctx.e.value.?, "def"));

    _ = try parser.parse("-e");
    try expect(ctx.e.value == null);
    try expect(parser.option_expecting_argument.? == &ctx.e);

    // reset option_
    parser.option_expecting_argument = null;
}
