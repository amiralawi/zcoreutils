const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;


const base_exe_name = "zcomm";
const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(
        \\Usage: {0s} [OPTION]... FILE1 FILE2
        \\Compare sorted files FILE1 and FILE2 line by line.
        \\
        \\When FILE1 or FILE2 (not both) is -, read standard input.
        \\
        \\With no options, produce three-column output.  Column one contains
        \\lines unique to FILE1, column two contains lines unique to FILE2,
        \\and column three contains lines common to both files.
        \\
        \\  -1              suppress column 1 (lines unique to FILE1)
        \\  -2              suppress column 2 (lines unique to FILE2)
        \\  -3              suppress column 3 (lines that appear in both files)
        \\
        \\  --check-order     check that the input is correctly sorted, even
        \\                      if all input lines are pairable
        \\  --nocheck-order   do not check that the input is correctly sorted
        \\  --output-delimiter=STR  separate columns with STR
        \\  --total           output a summary
        \\  -z, --zero-terminated    line delimiter is NUL, not newline
        \\      --help     display this help and exit
        \\      --version  output version information and exit
        \\
        \\Note, comparisons honor the rules specified by 'LC_COLLATE'.
        \\
        \\Examples:
        \\  comm -12 file1 file2  Print only lines present in both file1 and file2.
        \\  comm -3 file1 file2  Print lines in file1 not in file2, and vice versa.
        \\

        , .{ exe_name}
    );
}

const ExpectedOptionValType = enum { none };
var expected_option: ExpectedOptionValType = .none;

var flag_dispVersion = false;
var flag_dispHelp = false;
var flag_suppress_c1 = false;
var flag_suppress_c2 = false;
var flag_suppress_c3 = false;
var flag_zeroterminated = false;

var ignore_options = false;
pub fn test_option_validity_and_store(str: []const u8) bool {
    if(ignore_options){
        return false;
    }
    switch(expected_option){
        .none => {}
    }
    if(std.mem.startsWith(u8, str, "--")){
        return test_long_option_validity_and_store(str);
    }
    else if(std.mem.startsWith(u8, str, "-")){
        if(str.len == 1){
            return false;
        }
        var all_chars_valid_flags = true;
        for(str[1..]) |ch| {
            switch(ch){
                '1', '2', '3' => {},
                else => { all_chars_valid_flags = false; },
            }
        }

        if(!all_chars_valid_flags){
            return false;
        }

        for(str[1..]) |ch| {
            switch(ch){
                '1' => { flag_suppress_c1 = true; },
                '2' => { flag_suppress_c2 = true; },
                '3' => { flag_suppress_c3 = true; },
                'z' => { flag_zeroterminated = true; },
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
    else if(std.mem.eql(u8, option, "check-order")){
        // TODO
        return true;
    }
    else if(std.mem.eql(u8, option, "nocheck-order")){
        // TODO
        return true;
    }
    else if(std.mem.eql(u8, option, "total")){
        // TODO
        return true;
    }
    else if(std.mem.eql(u8, option, "zero-terminated")){
        // TODO
        return true;
    }
    else if(std.mem.startsWith(u8, option, "output-delimiter=")){
        // TODO
        return true;
    }

    return false;
}

pub fn report_fileopen_error(err: anyerror, filename: []const u8, exe_name: []const u8) !void {
    switch(err){          
        error.FileNotFound =>{
            try stderr.print("{s}: {s}: No such file or directory\n", .{exe_name, filename});
        },
        error.IsDir => {
            try stderr.print("{s}: {s}: Is a directory\n", .{exe_name, filename});
        },
        error.AccessDenied => {
            try stderr.print("{s}: {s}: Permission denied\n", .{exe_name, filename});
        },
        else => {
            try stderr.print("{s}: {s}: unrecognized error '{any}'\n", .{exe_name, filename, err});
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
    var filenames = args.items[0..nfilenames];

    if(filenames.len == 0){
        try stdout.print("{s}: missing operand", .{exe_name});
        try stdout.print("Try '{s} --help' for more information.", .{exe_name});
        return EXIT_FAILURE;
    }
    else if(filenames.len == 1){
        try stdout.print("{s}: missing operand after '{s}'", .{exe_name, filenames[0]});
        try stdout.print("Try '{s} --help' for more information.", .{exe_name});
        return EXIT_FAILURE;
    }
    else if(filenames.len > 2){
        try stdout.print("{s}: extra operand '{s}'", .{exe_name, filenames[2]});
        try stdout.print("Try '{s} --help' for more information.", .{exe_name});
        return EXIT_FAILURE;
    }

    //
    var f1: std.fs.File = cwd.openFile(filenames[0], .{}) catch |err|{
        try report_fileopen_error(err, exe_name, filenames[0]);
        return EXIT_FAILURE;
    };
    defer f1.close();
    var f2: std.fs.File = cwd.openFile(filenames[1], .{}) catch |err|{
        try report_fileopen_error(err, exe_name, filenames[1]);
        return EXIT_FAILURE;
    };
    defer f2.close();

    // TODO

    return EXIT_SUCCESS;
}