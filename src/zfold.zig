const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;

const base_exe_name = "zfold";
const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(
        \\Usage: {0s} [OPTION]... [FILE]...
        \\Wrap input lines in each FILE, writing to standard output.
        \\
        \\With no FILE, or when FILE is -, read standard input.
        \\
        \\Mandatory arguments to long options are mandatory for short options too.
        \\  -b, --bytes         count bytes rather than columns
        \\  -s, --spaces        break at spaces
        \\  -w, --width=WIDTH   use WIDTH columns instead of 80
        \\      --help     display this help and exit
        \\      --version  output version information and exit
        \\
    , .{exe_name});
}

const ExpectedOptionValType = enum { none };
var expected_option: ExpectedOptionValType = .none;

var flag_dispVersion = false;
var flag_dispHelp = false;
var flag_verbose = false;

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

const argtype = enum { none, optional, required };

pub fn cliArgumentCallback(comptime config: type) type {
    return *const fn (*config, []u8) anyerror!void;
}

// pub fn cliArgument(comptime config: type) type {
//     return struct{
//         charflag: u8,
//         longname: []const u8,
//         arg_type: argtype,
//         callback: cliArgumentCallback(config),
//     };
// }

const cliArgParser = struct {
    const callback = fn ([]const u8) anyerror!void;
    const rule = struct {
        flags: []const u8,
        longname: []const u8,
        arg_type: argtype,
        callback: *const callback,
    };

    rules: []rule,
    ignore_options: bool = true,
    extra_argument: ?*callback = null,
    rule_expecting_argument: ?*rule = null,
    errorSource: ?*rule = null,

    pub fn init(rules: []cliArgParseRule) cliArgParser {
        return cliArgParser{ .rules = rules };
    }

    pub fn parse(self: *cliArgParser, optionstr: []const u8) bool {
        if (self.ignore_options) {
            return false;
        }
        if (self.extra_argument) |cb| {
            self.extra_argument = null;
            try cb(optionstr);
            return true;
        }

        if (optionstr.len <= 1 or optionstr[0] != '-') {
            return false;
        }
        if (optionstr[1] == '-') {
            if (optionstr.len == 2) {
                ignore_options = true;
                return true;
            }

            //must be a long option
            var option = optionstr[2..optionstr.len];

            for (self.rules) |r| {
                if (!std.mem.startsWith(u8, option, r.name)) {
                    continue;
                }
                if (option.len == r.name) {
                    // exact match
                    if (r.arg_type == .required) {
                        // TODO - set extra_argument and collect on next pass
                        return error.MissingRequiredArgument;
                    }
                    r.callback(option[r.name.len + 1 .. option.len]);
                } else if (option[r.name.len] == '=') {
                    // assignment in-arg
                    if (r.arg_type == .none) {
                        return error.TakesNoArguments;
                    }
                    r.callback(option[r.name.len + 1 .. option.len]);
                } else {
                    // probably an argument collision
                    // eg. --help vs --helpme
                    continue;
                }
            }
        } else {
            // must be a short option
        }
        return false;
    }
};

const cliArgParseRule = struct {
    flags: []const u8,
    longname: []const u8,
    arg_type: argtype,
    callback: *const fn ([]const u8) anyerror!void,
};

const config_fold = struct {
    flagHelp: bool = false,
};

pub fn helpCallback(arg: []const u8) !void {
    _ = arg;
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
    var nfilenames: usize = 0;

    const arg_rules = [_]cliArgParseRule{
        .{ .flags = "h", .longname = "help", .arg_type = .none, .callback = helpCallback },
    };
    _ = arg_rules;

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

    for (filenames) |filename| {
        var file = cwd.createFile(filename, .{ .truncate = false }) catch |err| {
            try report_exe_error(err, filename, exe_name);
            continue;
        };
        if (flag_verbose) {
            try stdout.print("{s}: cannot dosomething '{s}': error desc'\n", .{ exe_name, filename });
        }

        defer file.close();
    }

    return EXIT_SUCCESS;
}
