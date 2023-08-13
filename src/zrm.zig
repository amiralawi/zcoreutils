const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;
var stdin: std.fs.File.Reader = undefined;

const base_exe_name = "zrm";
const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(
        \\Usage: {0s} [OPTION]... [FILE]...
        \\Remove (unlink) the FILE(s).
        \\
        \\CURRENTLY SUPPORTED OPTIONS
        \\      --help ............ display this help and exit
        \\      --version ......... output version information and exit
        \\  -f, --force ........... ignore nonexistent files and arguments, never prompt
        \\  -i                      prompt before every removal
        \\  -I                      prompt once before removing more than three files
        \\                          less intrusive than -i,
        \\                          while still giving protection against most mistakes
        \\
        \\      --interactive[=WHEN] Prompt according to WHEN:
        \\              --interactive=never
        \\              --interactive=once   equivalent to -I
        \\              --interactive=always equivalent to -i
        \\              --interactive        equivalent to -i
        \\
        \\  -r, -R, --recursive     remove directies and their contents recursively
        \\  -d, --dir               remove empty directories
        \\  -v, --verbose           explain what is being done
        \\
        \\By default, {1s} does not remove directories.  Use the --recursive (-r or -R)
        \\option to remove each listed directory, too, along with all of its contents.
        \\
        \\To remove a file whose name starts with a '-', for example '-foo',
        \\use one of these commands:
        \\  {0s} -- -foo
        \\
        \\  {0s} ./-foo
        \\
        \\Note that if you use rm to remove a file, it might be possible to recover
        \\some of its contents, given sufficient expertise and/or time.  For greater
        \\assurance that the contents are truly unrecoverable, consider using shred.
        \\
        \\
        \\
        \\UNIMPLEMENTED OPTIONS
        \\  -I                    NEED TO ADD -> or when removing recursively;
        \\                          
        \\      --one-file-system  when removing a hierarchy recursively, skip any
        \\                          directory that is on a file system different from
        \\                          that of the corresponding command line argument
        \\      --no-preserve-root  do not treat '/' specially
        \\      --preserve-root[=all]  do not remove '/' (default);
        \\                              with 'all', reject any command line argument
        \\                              on a separate device from its parent
        \\
        , .{ exe_name,  base_exe_name}
    );
}


const PromptType = enum {always, once, never};

var flag_dispVersion = false;
var flag_dispHelp = false;
var flag_removeDirectories = false;
var flag_recursive = false;
var flag_verbose = false;
var flag_force = false;

// var flag_interactiveStrict = false;
// var flag_interactiveOnce   = false;
// var flag_interactiveLax    = false;
// var flag_interactiveNever  = false;

var flag_oneFileSystem   = false;
var flag_noPreserveRoot  = false;
var flag_preserveRoot    = true;
var flag_preserveRootAll = false;

var prompt_behavior = PromptType.never;

var ignore_options = false;
pub fn test_option_validity_and_store(str: []const u8) bool {
    if(ignore_options){
        return false;
    }
    else if(util.u8str.startsWith(str, "--") and str.len > 1){
        return test_long_option_validity_and_store(str);
    }
    else if(util.u8str.startsWith(str, "-") and str.len > 1){
        var all_chars_valid_flags = true;
        for(str[1..]) |ch| {
            switch(ch){
                'f', 'v', 'r', 'R', 'd', 'i', 'I' => {},
                else => { all_chars_valid_flags = false; },
            }
        }

        if(!all_chars_valid_flags){
            return false;
        }

        for(str[1..]) |ch| {
            switch(ch){
                'i' => { prompt_behavior = .always; flag_force = false; },
                'f' => { prompt_behavior = .never; flag_force = true; },
                'I' => { prompt_behavior = .once; flag_force = false; },
                'r', 'R' => { flag_recursive = true; },
                'd' => { flag_removeDirectories = true; },
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
    else if(util.u8str.cmp(option, "help")){
        flag_dispHelp = true;
        return true;
    }
    else if(util.u8str.cmp(option, "interactive")){
        flag_force = false;
        prompt_behavior = .always;
        return true;
    }
    else if(util.u8str.cmp(option, "interactive=always")){
        flag_force = false;
        prompt_behavior = .always;
        return true;
    }
    else if(util.u8str.cmp(option, "interactive=once")){
        flag_force = false;
        prompt_behavior = .once;
        return true;
    }
    else if(util.u8str.cmp(option, "interactive=never")){
        prompt_behavior = .never;
        return true;
    }
    else if(util.u8str.cmp(option, "verbose")){
        flag_verbose = true;
        return true;
    }
    else if(util.u8str.cmp(option, "dir")){
        flag_removeDirectories = true;
        return true;
    }
    else if(util.u8str.cmp(option, "recursive")){
        flag_recursive = true;
        return true;
    }
    else if(util.u8str.cmp(option, "force")){
        flag_force = true;
        prompt_behavior = .never;
        return true;
    }
    // if(util.u8str.cmp(option, "one-file-system")){
    //     flag_oneFileSystem = true;
    //     return true;
    // }
    // if(util.u8str.cmp(option, "no-preserve-root")){
    //     flag_noPreserveRoot = true;
    //     return true;
    // }
    else if(util.u8str.cmp(option, "preserve-root")){
        flag_preserveRoot = true;
        return true;
    }
    return false;
}

pub fn input_confirmation() bool {
    var b = [1]u8{0};
    var nread = stdin.read(&b) catch {
        return false;
    };
    var val = (b[0] == 'Y') or (b[0] == 'y');

    // read to EOL
    while(nread != 0 and b[0] != '\n'){
        nread = stdin.read(&b) catch 0;
    }
    return val;
}

pub fn delete_file(filename: []const u8, cwd: std.fs.Dir) !file_type {
    if(cwd.deleteFile(filename)){
        return file_type.file;
    }
    else |errFile| {
        if(errFile == error.IsDir){
            if(flag_recursive){
                if(cwd.deleteTree(filename)) {
                    return file_type.dir;
                }
                else |errTree|{
                    return errTree;
                }
            }
            else if(flag_removeDirectories){
                if(cwd.deleteDir(filename)){
                    return file_type.dir;
                }
                else |errDir| {
                    return errDir;
                }
            }
        }
        return errFile;
    }
}

pub fn is_root(filename: []const u8) bool {
    // TODO - need to resolve symlinks, ../, ./, etc
    return util.u8str.cmp(filename, "/");
}

pub fn report_delete_error(err: anyerror, filename: []const u8, exe_name: []const u8) !void {
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

const file_type = enum { file, dir };

pub fn main() !u8 {
    stdout = std.io.getStdOut().writer();
    stderr = std.io.getStdErr().writer();
    stdin = std.io.getStdIn().reader();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();

    // TODO change args storage
    // TODO cli.args.appendToArrayList internally uses std.process.argsWithAllocator which also
    // TODO appends items to a std.ArrayList -> the system fills an ArrayList internally and uses
    // TODO that to fill an ArrayList externally which is pretty dumb.

    var args = std.ArrayList([]const u8).init(heapalloc);
    try cli.args.appendToArrayList(&args, heapalloc);
    var exe_name = args.items[0];

    // process options & update globals
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

    if(prompt_behavior == .once and filenames.len > 3){
        try stdout.print("{s}: remove {d} arguments? ", .{exe_name, filenames.len} );
        if(!input_confirmation()){
            return EXIT_SUCCESS;
        }
    }

    for(filenames) |filename| {
        var confirm_deletion = true;
        var filetype: []const u8 = "";

        if(is_root(filename)){
            try stderr.print("{s}: it is dangerous to operate recursively on '/'\n", .{exe_name});
            try stderr.print("{s}: use --no-preserve-root to override this failsafe\n", .{exe_name});
            confirm_deletion = flag_noPreserveRoot;
        }
        else if(prompt_behavior == .always){
            // TODO - investigate file type (empty file, non-empty, etc) and file permissions
            // filetype = "empty file", "regular file", "directory" or "empty directory"
            try stdout.print("{s}: remove {s} '{s}'? ", .{exe_name, filetype, filename} );
            confirm_deletion = input_confirmation();
        }

        if(!confirm_deletion){
            continue;
        }

        if(delete_file(filename, cwd)) |status| {
            filetype = if(status == .dir) "directory " else "file ";
            if(flag_verbose){
                try stdout.print("{s}: deleted {s}'{s}'\n", .{exe_name, filetype, filename});
            }
        }
        else |err| {
            try report_delete_error(err, filename, exe_name);
        }   
    }
    return EXIT_SUCCESS;
}