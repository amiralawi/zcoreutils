const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;

const base_exe_name = "zfalse";
const EXIT_FAILURE: u8 = 1;


pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(
        \\Usage: {0s} [ignored command line arguments]
        \\  or:  {0s} OPTION
        \\Exit with a status code indicating failure.
        \\
        \\      --help     display this help and exit
        \\      --version  output version information and exit
        \\
        \\NOTE: your shell may have its own version of false, which usually supersedes
        \\the version described here.  Please refer to your shell's documentation
        \\for details about the options it supports.
        \\
        , .{ exe_name}
    );
}

var flag_dispVersion = false;
var flag_dispHelp = false;

var ignore_options = false;
pub fn test_option_validity_and_store(str: []const u8) bool {
    if(ignore_options){
        return false;
    }
    if(std.mem.startsWith(u8, str, "--")){
        return test_long_option_validity_and_store(str);
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
    return false;
}


pub fn main() !u8 {
    stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();


    var args = std.ArrayList([]const u8).init(heapalloc);
    try cli.args.appendToArrayList(&args, heapalloc);
    var exe_name = args.items[0];

    for(args.items[1..]) |arg| {
        _ = test_option_validity_and_store(arg);
    }

    if(flag_dispHelp){
        try print_usage(exe_name);
    }
    else if(flag_dispVersion){
        try library.print_exe_version(stdout, base_exe_name);
    }
    
    return EXIT_FAILURE;
}