const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;


const base_exe_name = "zseq";
const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(
\\Usage: {0s} [OPTION]... LAST
\\  or:  {0s} [OPTION]... FIRST LAST
\\  or:  {0s} [OPTION]... FIRST INCREMENT LAST
\\Print numbers from FIRST to LAST, in steps of INCREMENT.
\\
\\Mandatory arguments to long options are mandatory for short options too.
\\  -f, --format=FORMAT      use printf style floating-point FORMAT
\\  -s, --separator=STRING   use STRING to separate numbers (default: \n)
\\  -w, --equal-width        equalize width by padding with leading zeroes
\\      --help     display this help and exit
\\      --version  output version information and exit
\\
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
        , .{ exe_name}
    );
}

const ExpectedOptionValType = enum { none, format, separator };
var expected_option: ExpectedOptionValType = .none;

var flag_dispVersion = false;
var flag_dispHelp = false;
var flag_equal_width = false;

var format_str: []const u8 = "";
var separator_str: []const u8 = "\n";

var ignore_options = false;
pub fn test_option_validity_and_store(str: []const u8) bool {
    if(ignore_options){
        return false;
    }
    else if(expected_option != .none){
        switch(expected_option){
            .format, => { format_str = str; },
            .separator, => { separator_str = str; },
            else => {},
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
                'f', 's', 'w' => {},
                else => { all_chars_valid_flags = false; },
            }
        }

        if(!all_chars_valid_flags){
            return false;
        }

        for(str[1..]) |ch| {
            switch(ch){
                'f' => { expected_option = .format; },
                's' => { expected_option = .separator; },
                'w' => { flag_equal_width = true; },
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
    else if(std.mem.eql(u8, option, "equal-width")){
        flag_equal_width = true;
        return true;
    }
    else if(std.mem.startsWith(u8, option, "separator=")){
        separator_str = option[10..];
        return true;
    }
    else if(std.mem.startsWith(u8, option, "format=")){
        format_str = option[10..];
        return true;
    }


    return false;
}

pub fn report_exe_error(err: anyerror, filename: []const u8, exe_name: []const u8) !void {
    // TODO - probably don't need this
    switch(err){          
        error.FileNotFound =>{
            try stderr.print("{s}: cannot remove '{s}': No such file or directory\n", .{exe_name, filename});
        },
        error.IsDir => {
            try stderr.print("{s}: cannot remove '{s}': Is a directory\n", .{exe_name, filename});
        },
        error.AccessDenied => {
            try stderr.print("{s}: cannot remove '{s}': Permission denied\n", .{exe_name, filename});
        },
        error.DirNotEmpty => {
            try stderr.print("{s}: cannot remove '{s}': Directory not empty\n", .{exe_name, filename});
        },
        else => {
            try stderr.print("{s}: cannot remove '{s}': unrecognized error '{any}'\n", .{exe_name, filename, err});
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
    var exe_name = args.items[0];

    const cwd = std.fs.cwd();
    _ = cwd;
    var n_unprocessed: usize = 0;
    for(args.items[1..]) |arg| {
        // Move anything that isn't a valid option to the beginning of args - take the bottom
        // slice for use as unprocessed_args later
        if(!test_option_validity_and_store(arg)){
            args.items[n_unprocessed] = arg;
            n_unprocessed += 1;
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
    var unprocessed_args = args.items[0..n_unprocessed];

    var first: i32 = undefined;
    var last: i32 = undefined;
    var increment: i32 = undefined;
    switch(unprocessed_args.len){
        0 => {
            try stdout.print("{s}: missing operand\n", .{exe_name});
            try stdout.print("Try '{s} --help' for more information.\n", .{exe_name});
            return EXIT_FAILURE;
        },
        1 => {
            first     = 1;
            increment = 1;
            last      = try std.fmt.parseInt(i32, unprocessed_args[0], 10);
        },
        2 => {
            first     = try std.fmt.parseInt(i32, unprocessed_args[0], 10);
            increment = 1;
            last      = try std.fmt.parseInt(i32, unprocessed_args[1], 10);
        },
        3 => {
            first     = try std.fmt.parseInt(i32, unprocessed_args[0], 10);
            increment = try std.fmt.parseInt(i32, unprocessed_args[1], 10);
            last      = try std.fmt.parseInt(i32, unprocessed_args[2], 10);
        },
        else =>{
            try stdout.print("{s}: extra operand '{s}'\n", .{exe_name, unprocessed_args[3]});
            try stdout.print("Try '{s} --help' for more information.\n", .{exe_name});
            return EXIT_FAILURE;
        }
    }

    // try stdout.print("{d} {d} {d}\n", .{first, increment, last});

    var i = first;
    while(i <= last) : (i+=increment){
        try stdout.print("{d}{s}", .{i, separator_str});
    }


    return EXIT_SUCCESS;
}