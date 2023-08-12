const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;


const base_exe_name = "zrm";
const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(
        \\Usage: {0s} [OPTION]... FILE...
        \\Short Description of what this utility does.
        \\
        \\A FILE argument that does not exist is created empty, unless -c or -h
        \\is supplied.
        \\
        \\A FILE argument string of - is handled specially and causes touch to
        \\change the times of the file associated with standard output.
        \\
        \\Mandatory arguments to long options are mandatory for short options too.
        \\  -a                     change only the access time
        \\  -c, --no-create        do not create any files
        \\  -d, --date=STRING      parse STRING and use it instead of current time
        \\  -f                     (ignored)
        \\  -h, --no-dereference   affect each symbolic link instead of any referenced
        \\                         file (useful only on systems that can change the
        \\                         timestamps of a symlink)
        \\  -m                     change only the modification time
        \\  -r, --reference=FILE   use this file's times instead of current time
        \\  -t STAMP               use [[CC]YY]MMDDhhmm[.ss] instead of current time
        \\      --time=WORD        change the specified time:
        \\                           WORD is access, atime, or use: equivalent to -a
        \\                           WORD is modify or mtime: equivalent to -m
        \\      --help     display this help and exit
        \\      --version  output version information and exit
        \\
        \\Note that the -d and -t options accept different time-date formats.
        \\
        , .{ exe_name}
    );
}

const ExpectedOptionValType = enum { none };
var expected_option: ExpectedOptionValType = .none;

var flag_dispVersion = false;
var flag_dispHelp = false;
var flag_verbose = false;

var ignore_options = false;
pub fn test_option_validity_and_store(str: []const u8) bool {
    if(ignore_options){
        return false;
    }
    switch(expected_option){
        .none => {}
    }
    if(util.u8str.startsWith(str, "--")){
        return test_option_validity_and_store(str);
    }
    else if(util.u8str.startsWith(str, "-") and str.len > 1){
        var all_chars_valid_flags = true;
        for(str[1..]) |ch| {
            switch(ch){
                
                else => { all_chars_valid_flags = false; },
            }
        }

        if(!all_chars_valid_flags){
            return false;
        }

        for(str[1..]) |ch| {
            switch(ch){
                else => unreachable,
            }
        }
        return true;
    }
    return false;
}

pub fn test_long_option_validity_and_store(str: []const u8) bool {
    // this function only gets called when str starts with "--"
    if(util.u8str.cmp(str, "--")){
        ignore_options = true;
        return true;
    }

    var option = str[2..];
    if(util.u8str.cmp(option, "version")){
        flag_dispVersion = true;
        return true;
    }
    if(util.u8str.cmp(option, "help")){
        flag_dispHelp = true;
        return true;
    }
}

pub fn report_exe_error(err: anyerror, filename: []const u8, exe_name: []const u8) !void {
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

    for(filenames) |filename| {
        var file = cwd.createFile(filename, .{ .truncate = false }) catch |err| {
            try report_exe_error(err, filename, exe_name);
            continue;
        };
        if(flag_verbose){
            try stdout.print("{s}: cannot dosomething '{s}': error desc'\n", .{exe_name, filename});
        }


        
        defer file.close();
    }

    return EXIT_SUCCESS;
}