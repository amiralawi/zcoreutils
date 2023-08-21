const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;

const base_exe_name = "TEMPLATE";
const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(

        \\Usage: {0s} [OPTION]... DIRECTORY...
        \\Remove the DIRECTORY(ies), if they are empty.
        \\
        \\      --ignore-fail-on-non-empty
        \\                  ignore each failure that is solely because a directory
        \\                    is non-empty
        \\  -p, --parents   remove DIRECTORY and its ancestors; e.g., 'rmdir -p a/b/c' is
        \\                    similar to 'rmdir a/b/c a/b a'
        \\  -v, --verbose   output a diagnostic for every directory processed
        \\      --help     display this help and exit
        \\      --version  output version information and exit
        \\
        , .{ exe_name}
    );
}

const ExpectedOptionValType = enum { none };
var expected_option: ExpectedOptionValType = .none;

var flag_dispVersion = false;
var flag_dispHelp = false;
var flag_verbose = false;
var flag_parents = false;
var flag_ingoreFailOnNonEmpty = false;

var ignore_options = false;
pub fn test_option_validity_and_store(str: []const u8) bool {
    if(ignore_options){
        return false;
    }
    switch(expected_option){
        .none => {}
    }
    if(std.mem.startsWith(u8, str, "--")){
        return test_option_validity_and_store(str);
    }
    else if(std.mem.startsWith(u8, str, "-") and str.len > 1){
        var all_chars_valid_flags = true;
        for(str[1..]) |ch| {
            switch(ch){
                'p', 'v' => {},
                else => { all_chars_valid_flags = false; },
            }
        }

        if(!all_chars_valid_flags){
            return false;
        }

        for(str[1..]) |ch| {
            switch(ch){
                'p' => { flag_parents = true; },
                'v' => { flag_verbose = true; },
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
    if(util.u8str.cmp(option, "parents")){
        flag_parents = true;
        return true;
    }
    if(util.u8str.cmp(option, "verbose")){
        flag_verbose = true;
        return true;
    }
    if(util.u8str.cmp(option, "ignore-fail-on-non-empty")){
        flag_ingoreFailOnNonEmpty = true;
        return true;
    }
}

pub fn report_rmdir_error(err: anyerror, filename: []const u8, exe_name: []const u8) !void {
    switch(err){          
        error.FileNotFound =>{
            try stderr.print("{s}: failed to remove '{s}': No such file or directory\n", .{exe_name, filename});
        },
        error.AccessDenied => {
            try stderr.print("{s}: failed to remove '{s}': Permission denied\n", .{exe_name, filename});
        },
        error.DirNotEmpty => {
            if(flag_ingoreFailOnNonEmpty){ return; }
            try stderr.print("{s}: failed to remove '{s}': Directory not empty\n", .{exe_name, filename});
        },
        else => {
            try stderr.print("{s}: failed to remove '{s}': unrecognized error '{any}'\n", .{exe_name, filename, err});
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

        // allow early exit
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
        try stderr.print("{s}: missing operand\n", .{exe_name});
        try stderr.print("Try '{s} --help' for more information.\n", .{exe_name});
        return EXIT_FAILURE;
    }

    for(filenames) |filename| {
        if(flag_verbose){
            try stdout.print("{0s}: removing directory, '{1s}'\n", .{exe_name, filename});
        }
        cwd.deleteDir(filename) catch |err| {
            try report_rmdir_error(err, filename, exe_name);
        };

        if(flag_parents){
            var it = try std.fs.path.componentIterator(filename);
            _ = it.last();
            while(it.previous()) |c| {
                if(flag_verbose){
                    try stdout.print("{0s}: removing directory, '{1s}'\n", .{exe_name, c.path});
                }

                cwd.deleteDir(c.path) catch |err| {
                    try report_rmdir_error(err, c.path, exe_name);
                };
            }
        }
    }

    return EXIT_SUCCESS;
}