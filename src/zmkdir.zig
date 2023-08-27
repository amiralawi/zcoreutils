const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;

const base_exe_name = "mkdir";
const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(

        \\Usage: {0s} [OPTION]... DIRECTORY...
        \\Create the DIRECTORY(ies), if they do not already exist.
        \\
        \\Mandatory arguments to long options are mandatory for short options too.
        \\  -m, --mode=MODE   set file mode (as in chmod), not a=rwx - umask
        \\  -p, --parents     no error if existing, make parent directories as needed
        \\  -v, --verbose     print a message for each created directory
        \\  -Z                   set SELinux security context of each created directory
        \\                         to the default type
        \\      --context[=CTX]  like -Z, or if CTX is specified then set the SELinux
        \\                         or SMACK security context to CTX
        \\      --help     display this help and exit
        \\      --version  output version information and exit
        \\
        , .{ exe_name}
    );


}

const ExpectedOptionValType = enum { mode, context, none };
var expected_option: ExpectedOptionValType = .none;

var flag_dispVersion = false;
var flag_dispHelp = false;
var flag_verbose = false;
var flag_parents = false;

var ignore_options = false;
pub fn test_option_validity_and_store(str: []const u8) bool {
    if(ignore_options){
        return false;
    }
    switch(expected_option){
        .none => {},
        .mode => {},
        .context => {},
    }
    if(std.mem.startsWith(u8, str, "--")){
        return test_option_validity_and_store(str);
    }
    else if(std.mem.startsWith(u8, str, "-") and str.len > 1){
        var all_chars_valid_flags = true;
        for(str[1..]) |ch| {
            switch(ch){
                // 'Z' => {},
                'p', 'v', 'm' => {},
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
                'm' => { expected_option = .mode; },
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
    // if(std.mem.startsWith(u8, option, "context")){
    //     // TODO
    //     return true;
    // }
}

pub fn report_mkdir_error(err: anyerror, filename: []const u8, exe_name: []const u8) !void {
    switch(err){          
        error.FileNotFound =>{
            try stderr.print("{s}: cannot create directory '{s}': No such file or directory\n", .{exe_name, filename});
        },
        error.AccessDenied => {
            try stderr.print("{s}: cannot create directory '{s}': Permission denied\n", .{exe_name, filename});
        },
        error.PathAlreadyExists => {
            try stderr.print("{s}: cannot create directory '{s}': File exists\n", .{exe_name, filename});
        },
        else => {
            try stderr.print("{s}: cannot create directory '{s}': unrecognized error '{any}'\n", .{exe_name, filename, err});
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

    for(filenames) |dirpath| {
        if(flag_parents){
            var it = try std.fs.path.componentIterator(dirpath);
            var component = it.first();
            while(component) |c| {
                component = it.next();

                cwd.makeDir(c.path) catch |err| switch(err){
                    error.PathAlreadyExists =>{
                        continue;
                    },
                    else => {
                        try report_mkdir_error(err, c.path, exe_name);
                        break;
                    },
                };

                if(flag_verbose){
                    try stdout.print("{0s}: created directory w/parents '{1s}'\n", .{exe_name, c.path});
                }
            }
        }
        else{
            try stdout.print("verbose output '{s}'\n", .{dirpath});
            cwd.makeDir(dirpath) catch |err|{
                try report_mkdir_error(err, dirpath, exe_name);
            };

            if(flag_verbose){
                try stdout.print("{0s}: created directory '{1s}'\n", .{exe_name, dirpath});
            }
        }
    }

    return EXIT_SUCCESS;
}