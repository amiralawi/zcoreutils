const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;

const base_exe_name = "zpwd";
const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(
        \\Usage: {0s} [OPTION]...
        \\Print the full filename of the current working directory.
        \\
        \\  -L, --logical   use PWD from environment, even if it contains symlinks
        \\  -P, --physical  avoid all symlinks
        \\      --help     display this help and exit
        \\      --version  output version information and exit
        \\
        \\If no option is specified, -P is assumed.
        \\
        \\NOTE: your shell may have its own version of pwd, which usually supersedes
        \\the version described here.  Please refer to your shell's documentation
        \\for details about the options it supports.
        \\
    , .{exe_name});
}

const ExpectedOptionValType = enum { none };

var expected_option: ExpectedOptionValType = .none;

var flag_dispVersion = false;
var flag_dispHelp = false;
var flag_logical = true;
var flag_physical = false;

var ignore_options = false;
pub fn test_option_validity_and_store(str: []const u8) bool {
    if (ignore_options) {
        return false;
    } else if (expected_option != .none) {
        switch (expected_option) {
            .none => {},
        }
        expected_option = .none;
        return true;
    } else if (std.mem.startsWith(u8, str, "--")) {
        return test_long_option_validity_and_store(str);
    } else if (std.mem.startsWith(u8, str, "-") and str.len > 1) {
        var all_chars_valid_flags = true;
        for (str[1..]) |ch| {
            switch (ch) {
                'L', 'P' => {},
                else => {
                    all_chars_valid_flags = false;
                },
            }
        }

        if (!all_chars_valid_flags) {
            return false;
        }

        for (str[1..]) |ch| {
            switch (ch) {
                'L' => {
                    flag_logical = true;
                    flag_physical = false;
                },
                'P' => {
                    flag_logical = false;
                    flag_physical = true;
                },
                else => unreachable,
            }
        }
        return true;
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
    } else if (std.mem.eql(u8, option, "logical")) {
        flag_logical = true;
        flag_physical = false;
        return true;
    } else if (std.mem.eql(u8, option, "physical")) {
        flag_logical = false;
        flag_physical = true;
        return true;
    }

    return false;
}

pub fn report_exe_error(err: anyerror, filename: []const u8, exe_name: []const u8) !void {
    switch (err) {
        error.FileNotFound => {
            try stderr.print("{s}: cannot remove '{s}': No such file or directory\n", .{ exe_name, filename });
        },
        error.IsDir => {
            try stderr.print("{s}: cannot remove '{s}': Is a directory\n", .{ exe_name, filename });
        },
        error.AccessDenied => {
            try stderr.print("{s}: cannot remove '{s}': Permission denied\n", .{ exe_name, filename });
        },
        error.DirNotEmpty => {
            try stderr.print("{s}: cannot remove '{s}': Directory not empty\n", .{ exe_name, filename });
        },
        else => {
            try stderr.print("{s}: cannot remove '{s}': unrecognized error '{any}'\n", .{ exe_name, filename, err });
        },
    }
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

    const cwd = std.fs.cwd();
    _ = cwd;
    for (args.items[1..]) |arg| {
        // Move anything that isn't a valid option to the beginning of args - take the bottom
        // slice for use as filenames later
        _ = test_option_validity_and_store(arg);

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

    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var cwd_path: []u8 = undefined;
    //cwd_path = try cwd.realpath(".", &path_buffer);
    //cwd_path = try std.os.getcwd(&path_buffer);
    cwd_path = try std.process.getCwd(&path_buffer);
    try stdout.print("{s}\n", .{cwd_path});

    return EXIT_SUCCESS;
}
