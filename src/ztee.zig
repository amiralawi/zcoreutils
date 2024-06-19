const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;

const base_exe_name = "ztee";
const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(
        \\Usage: {0s} [OPTION]... [FILE]...
        \\Copy standard input to each FILE, and also to standard output.
        \\
        \\  -a, --append              append to the given FILEs, do not overwrite
        \\      --help     display this help and exit
        \\      --version  output version information and exit
        \\
        \\UNIMPLEMENTED OPTIONS:
        \\  -i, --ignore-interrupts   ignore interrupt signals
        \\  -p                        diagnose errors writing to non pipes
        \\      --output-error[=MODE]   set behavior on write error.  See MODE below
        \\
        \\MODE determines behavior with write errors on the outputs:
        \\  'warn'         diagnose errors writing to any output
        \\  'warn-nopipe'  diagnose errors writing to any output not a pipe
        \\  'exit'         exit on error writing to any output
        \\  'exit-nopipe'  exit on error writing to any output not a pipe
        \\The default MODE for the -p option is 'warn-nopipe'.
        \\The default operation when --output-error is not specified, is to
        \\exit immediately on error writing to a pipe, and diagnose errors
        \\writing to non pipe outputs.
        \\
    , .{exe_name});
}

const ExpectedOptionValType = enum { none };
var expected_option: ExpectedOptionValType = .none;

var flag_dispVersion = false;
var flag_dispHelp = false;
var flag_verbose = false;
var flag_append = false;

var ignore_options = false;
pub fn test_option_validity_and_store(str: []const u8) bool {
    if (ignore_options) {
        return false;
    }
    switch (expected_option) {
        .none => {},
    }
    if (std.mem.startsWith(u8, str, "--")) {
        return test_long_option_validity_and_store(str);
    } else if (std.mem.startsWith(u8, str, "-") and str.len > 1) {
        var all_chars_valid_flags = true;
        for (str[1..]) |ch| {
            switch (ch) {
                'a' => {},
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
                'a' => {
                    flag_append = true;
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
    } else if (std.mem.eql(u8, option, "append")) {
        flag_append = true;
        return true;
    }

    return false;
}

pub fn report_fileopen_error(err: anyerror, filename: []const u8, exe_name: []const u8) !void {
    switch (err) {
        error.FileNotFound => {
            // TODO - pretty sure this doesn't occur
            try stderr.print("{s}: '{s}': No such file or directory\n", .{ exe_name, filename });
        },
        error.IsDir => {
            try stderr.print("{s}: {s}: Is a directory\n", .{ exe_name, filename });
        },
        error.AccessDenied => {
            try stderr.print("{s}: {s}: Permission denied\n", .{ exe_name, filename });
        },
        else => {
            try stderr.print("{s}: {s}: unrecognized error '{any}'\n", .{ exe_name, filename, err });
        },
    }
}

pub fn main() !u8 {
    var exe_return: u8 = EXIT_SUCCESS;
    stdout = std.io.getStdOut().writer();
    stderr = std.io.getStdErr().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();

    var args = std.ArrayList([]const u8).init(heapalloc);
    try cli.args.appendToArrayList(&args, heapalloc);
    const exe_name = args.items[0];

    const cwd = std.fs.cwd();
    var nfilenames: usize = 0;
    for (args.items[1..]) |arg| {
        // Move anything that isn't a valid option to the beginning of args - take the bottom
        // slice for use as filenames later
        if (!test_option_validity_and_store(arg)) {
            args.items[nfilenames] = arg;
            nfilenames += 1;
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
    const filenames = args.items[0..nfilenames];

    try stdout.print("append={}\n", .{flag_append});

    const flags: std.fs.File.CreateFlags = .{ .truncate = !flag_append };

    // open all output files
    var files = try std.ArrayList(std.fs.File).initCapacity(heapalloc, filenames.len + 1);
    try files.append(std.io.getStdOut());
    for (filenames) |fname| {
        var f = cwd.createFile(fname, flags) catch |err| {
            try report_fileopen_error(err, fname, exe_name);
            exe_return = EXIT_FAILURE;
            continue;
        };
        try f.seekFromEnd(0);
        try files.append(f);
    }
    defer {
        for (files.items[1..]) |f| {
            f.close();
        }
    }

    const buffer_size = 2048;
    var buffer: [buffer_size]u8 = undefined;

    const stdin = std.io.getStdIn();
    var finished = false;
    while (!finished) {
        const nread = try stdin.read(&buffer);
        const readslice = buffer[0..nread];
        for (files.items) |f| {
            _ = try f.write(readslice);
        }
        finished = (nread == 0);
    }

    return exe_return;
}
