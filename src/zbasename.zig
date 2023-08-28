const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;


const base_exe_name = "TEMPLATE FIXME TODO";
const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(
        \\Usage: {0s} NAME [SUFFIX]
        \\  or:  {0s} OPTION... NAME...
        \\Print NAME with any leading directory components removed.
        \\If specified, also remove a trailing SUFFIX.
        \\
        \\Mandatory arguments to long options are mandatory for short options too.
        \\  -a, --multiple       support multiple arguments and treat each as a NAME
        \\  -s, --suffix=SUFFIX  remove a trailing SUFFIX; implies -a
        \\  -z, --zero           end each output line with NUL, not newline
        \\      --help     display this help and exit
        \\      --version  output version information and exit
        \\
        \\Examples:
        \\  basename /usr/bin/sort          -> "sort"
        \\  basename include/stdio.h .h     -> "stdio"
        \\  basename -s .h include/stdio.h  -> "stdio"
        \\  basename -a any/str1 any/str2   -> "str1" followed by "str2"
        \\
        , .{ exe_name}
    );
}

const ExpectedOptionValType = enum { none, suffix };
var expected_option: ExpectedOptionValType = .none;

var flag_dispVersion = false;
var flag_dispHelp = false;
var flag_multiple = false;

var suffix: []const u8 = "";
var separator: u8 = '\n';

var ignore_options = false;
pub fn test_option_validity_and_store(str: []const u8) bool {
    if(ignore_options){
        return false;
    }
    else if(expected_option != .none){
        switch(expected_option){
            .none   => {},
            .suffix => { suffix = str; },
        }
        expected_option = .none;
        return true;
    }
    else if(std.mem.startsWith(u8, str, "--")){
        return test_long_option_validity_and_store(str);
    }
    else if(std.mem.startsWith(u8, str, "-") and str.len > 1){
        var all_chars_valid_flags = true;
        for(str[1..]) |ch| {
            switch(ch){
                'a', 's', 'z' => {},
                else => { all_chars_valid_flags = false; },
            }
        }

        if(!all_chars_valid_flags){
            return false;
        }

        for(str[1..]) |ch| {
            switch(ch){
                'a' => { flag_multiple = true; },
                's' => { flag_multiple = true; expected_option = .suffix; },
                'z' => { separator = '\x00'; },
                else => unreachable,
            }
        }
        return true;
    }
    return false;
}

pub fn test_long_option_validity_and_store(str: []const u8) bool {
    // this function only gets called when str starts with "--"
    if(std.mem.eql(u8, str, "--")){
        ignore_options = true;
        return true;
    }

    var option = str[2..];
    if(std.mem.eql(u8, option, "version")){
        flag_dispVersion = true;
        return true;
    }
    else if(std.mem.eql(u8, option, "help")){
        flag_dispHelp = true;
        return true;
    }
    else if(std.mem.eql(u8, option, "multiple")){
        flag_multiple = true;
        return true;
    }
    else if(std.mem.eql(u8, option, "zero")){
        separator = '\x00';
        return true;
    }
    else if(std.mem.startsWith(u8, option, "suffix=")){
        suffix = option[7..];
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
    var exe_name = args.items[0];

    var nfilenames: usize = 0;
    for(args.items[1..]) |arg| {
        // Move anything that isn't a valid option to the beginning of args - take the bottom
        // slice for use as filenames later
        if(!test_option_validity_and_store(arg)){
            args.items[nfilenames] = arg;
            nfilenames += 1;
        }

        // do this in the loop to allow early exit
        if(flag_dispHelp){
            try print_usage(exe_name);
            return EXIT_SUCCESS;
        }
        if(flag_dispVersion){
            try library.print_exe_version(stdout, base_exe_name);
            return EXIT_SUCCESS;
        }
    }
    if(!flag_multiple) { nfilenames = @min(1, nfilenames); }
    var filenames = args.items[0..nfilenames];

    if (filenames.len == 0){
        try stdout.print("{s}: missing operand", .{exe_name});
        try stdout.print("Try '{s} --help' for more information.", .{exe_name});
        return EXIT_FAILURE;
    }

    for(filenames) |filename| {
        var f: []const u8 = std.fs.path.basename(filename);
        if(std.mem.endsWith(u8, filename, suffix)){
            f = f[0..f.len - suffix.len];
        }
        try stdout.print("{s}{c}", .{ f, separator });
    }

    return EXIT_SUCCESS;
}