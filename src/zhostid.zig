const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;

const base_exe_name = "hostid";
const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(
        \\Usage: {0s} [OPTION]
        \\Print the numeric identifier (in hexadecimal) for the current host.
        \\
        \\      --help     display this help and exit
        \\      --version  output version information and exit
        \\
    , .{exe_name});
}

var flag_dispVersion = false;
var flag_dispHelp = false;

var ignore_options = false;
pub fn test_option_validity_and_store(str: []const u8) bool {
    if (ignore_options) {
        return false;
    }

    if (std.mem.startsWith(u8, str, "--")) {
        return test_long_option_validity_and_store(str);
    }
    return false;
}

pub fn test_long_option_validity_and_store(str: []const u8) bool {
    // this function only gets called when str starts with "--"
    if (std.mem.eql(u8, str, "--")) {
        ignore_options = true;
        return true;
    }

    const option = str[2..];
    if (std.mem.eql(u8, option, "version")) {
        flag_dispVersion = true;
        return true;
    } else if (std.mem.eql(u8, option, "help")) {
        flag_dispHelp = true;
        return true;
    }

    return false;
}

pub fn main() !u8 {
    stdout = std.io.getStdOut().writer();
    stderr = std.io.getStdErr().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();

    var args = std.ArrayList([]const u8).init(heapalloc);
    try cli.args.appendToArrayList(&args, heapalloc);
    const exe_name = args.items[0];

    var n_unprocessed: usize = 0;
    for (args.items[1..]) |arg| {
        // Move anything that isn't a valid option to the beginning of args - take the bottom
        // slice for use as unprocessed_args later
        if (!test_option_validity_and_store(arg)) {
            args.items[n_unprocessed] = arg;
            n_unprocessed += 1;
        }

        // do this in the loop to allow early exit
        if (flag_dispHelp) {
            try print_usage(exe_name);
            return EXIT_SUCCESS;
        }
        if (flag_dispVersion) {
            try library.print_exe_version(stdout, base_exe_name);
            return EXIT_SUCCESS;
        }
    }
    const unprocessed_args = args.items[0..n_unprocessed];
    _ = unprocessed_args;

    // TODO - no implementation

    return EXIT_SUCCESS;
}
