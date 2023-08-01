const util = @import("./util.zig");
const std = @import("std");

fn append_cli_args(container: *std.ArrayList([]const u8)) !void {
    var argiter = std.process.args();
    while (argiter.next()) |arg| {
        try container.append(arg);
    }
}

var options_n = false;
var options_E = false;
var options_e = false;
var args: std.ArrayList([]const u8) = undefined;
var args_to_print: std.ArrayList([]const u8) = undefined;

fn parse_cli_args() !void {
    for (args.items[1..]) |arg| {
        //if (arg.len > 1 and util.string.startsWith(&arg, "-") and util.string.countChar(&arg, '-') == 1) {
        if (util.u8str.startsWith(arg, "-")) {
            var arg_is_printable = false;
            var loop_has_n = false;
            var loop_has_E = false;
            var loop_has_e = false;

            for (arg[1..]) |ch| {
                switch (ch) {
                    'n' => {
                        loop_has_n = true;
                    },
                    'e' => {
                        loop_has_e = true;
                        loop_has_E = false;
                    },
                    'E' => {
                        loop_has_E = true;
                        loop_has_e = false;
                    },
                    else => {
                        arg_is_printable = true;
                    },
                }
            }

            if (arg_is_printable) {
                try args_to_print.append(arg);
            } else {
                if (loop_has_n) {
                    options_n = true;
                }
                if (loop_has_E) {
                    options_E = true;
                    options_e = false;
                }
                if (loop_has_e) {
                    options_E = false;
                    options_e = true;
                }
            }
        } else {
            try args_to_print.append(arg);
        }
    }
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // get CLI args
    args = std.ArrayList([]const u8).init(allocator);
    args_to_print = std.ArrayList([]const u8).init(allocator);
    try append_cli_args(&args);

    try parse_cli_args();

    // now do the echoing
    // TODO: add support for escape characters (options -e and -E)
    var n_printable = args_to_print.items.len;
    for (args_to_print.items, 1..) |arg, index| {
        var suffix = if (index == n_printable) "" else " ";
        try stdout.print("{s}{s}", .{ arg, suffix });
    }

    if (options_n == false) {
        try stdout.print("\n", .{});
    }
}
