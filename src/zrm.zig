const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();
const stdin = std.io.getStdIn().reader();

const base_exe_name = "zrm";

pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(
        \\Usage: {s} [OPTION]... [FILE]...
        \\Remove (unlink) the FILE(s).
        \\
        \\CURRENTLY SUPPORTED OPTIONS
        \\      --help ............ display this help and exit
        \\      --version ......... output version information and exit
        \\
        \\UNIMPLEMENTED OPTIONS
        \\  -f, --force           ignore nonexistent files and arguments, never prompt
        \\  -i                    prompt before every removal
        \\  -I                    prompt once before removing more than three files, or
        \\                          when removing recursively; less intrusive than -i,
        \\                          while still giving protection against most mistakes
        \\      --interactive[=WHEN]  prompt according to WHEN: never, once (-I), or
        \\                          always (-i); without WHEN, prompt always
        \\      --one-file-system  when removing a hierarchy recursively, skip any
        \\                          directory that is on a file system different from
        \\                          that of the corresponding command line argument
        \\      --no-preserve-root  do not treat '/' specially
        \\      --preserve-root[=all]  do not remove '/' (default);
        \\                              with 'all', reject any command line argument
        \\                              on a separate device from its parent
        \\  -r, -R, --recursive   remove directories and their contents recursively
        \\  -d, --dir             remove empty directories
        \\  -v, --verbose         explain what is being done
        \\
        \\By default, rm does not remove directories.  Use the --recursive (-r or -R)
        \\option to remove each listed directory, too, along with all of its contents.
        \\
        \\To remove a file whose name starts with a '-', for example '-foo',
        \\use one of these commands:
        \\  rm -- -foo
        \\
        \\  rm ./-foo
        \\
        \\Note that if you use rm to remove a file, it might be possible to recover
        \\some of its contents, given sufficient expertise and/or time.  For greater
        \\assurance that the contents are truly unrecoverable, consider using shred.
        \\
        , .{ exe_name }
    );
}

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

const PromptType = enum {always, once, never};

var ignore_options = false;
pub fn test_option_validity_and_store(str: []const u8) bool {
    if(ignore_options){
        return false;
    }
    if(util.u8str.cmp(str, "--")){
        ignore_options = true;
        return true;
    }
    if(util.u8str.cmp(str, "--version")){
        flag_dispVersion = true;
        return true;
    }
    if(util.u8str.cmp(str, "--help")){
        flag_dispHelp = true;
        return true;
    }
    if(util.u8str.cmp(str, "--interactive")){
        flag_force = false;
        prompt_behavior = .always;
        return true;
    }
    if(util.u8str.cmp(str, "--interactive=always")){
        flag_force = false;
        prompt_behavior = .always;
        return true;
    }
    if(util.u8str.cmp(str, "--interactive=once")){
        flag_force = false;
        prompt_behavior = .always;
        return true;
    }
    if(util.u8str.cmp(str, "--interactive=never")){
        prompt_behavior = .always;
        return true;
    }
    if(util.u8str.cmp(str, "--verbose")){
        flag_verbose = true;
        return true;
    }
    if(util.u8str.cmp(str, "--dir")){
        flag_removeDirectories = true;
        return true;
    }
    if(util.u8str.cmp(str, "--recursive")){
        flag_recursive = true;
        return true;
    }
    if(util.u8str.cmp(str, "--force")){
        flag_force = true;
        prompt_behavior = .never;
        return true;
    }
    // if(util.u8str.cmp(str, "--one-file-system")){
    //     flag_oneFileSystem = true;
    //     return true;
    // }
    // if(util.u8str.cmp(str, "--no-preserve-root")){
    //     flag_noPreserveRoot = true;
    //     return true;
    // }
    if(util.u8str.cmp(str, "--preserve-root")){
        flag_preserveRoot = true;
        return true;
    }
    // if(util.u8str.cmp(str, "--preserve-root=all")){
    //     flag_preserveRootAll = true;
    //     return true;
    // }
    if(util.u8str.startsWith(str, "-") and str.len > 1){
        var all_chars_valid_flags = true;
        for(str[1..]) |ch| {
            switch(ch){
                'f', 'v' => {},
                'r', 'R' => {},
                'd' => {},
                'i' => {},
                'I' => {},
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
    

    // unrecognized option, probably a filename
    return false;
}

const delete_status = enum {
    file_deleted, dir_deleted, deletion_failed
};


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

pub fn delete_file(filename: []const u8, cwd: std.fs.Dir) !delete_status {
    if(cwd.deleteFile(filename)){
        return delete_status.file_deleted;
    }
    else |errFile| {
        if(errFile == error.IsDir){
            if(flag_recursive){
                if(cwd.deleteTree(filename)) {
                    return delete_status.dir_deleted;
                }
                else |errTree|{
                    return errTree;
                }
                
            }
            else if(flag_removeDirectories){
                if(cwd.deleteDir(filename)){
                    return delete_status.dir_deleted;
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

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();

    var args = std.ArrayList([]const u8).init(heapalloc);
    try cli.args.appendToArrayList(&args, heapalloc);

    var filenames = try std.ArrayList([]const u8).initCapacity(heapalloc, args.items.len);
    var options = try std.ArrayList([]const u8).initCapacity(heapalloc, args.items.len);

    var exe_name = args.items[0];

    // process options & update globals
    const cwd = std.fs.cwd();
    for(args.items[1..]) |arg| {
        if(!test_option_validity_and_store(arg)){
            try filenames.append(arg);
        }
        else{
            try options.append(arg);
        }
    }

    // now execute rm
    if(flag_dispHelp){
        try print_usage(exe_name);
        return;
    }
    if(flag_dispVersion){
        try library.print_exe_version(base_exe_name);
        return;
    }

    if(prompt_behavior == .once and filenames.items.len > 3){
        try stdout.print("{s}: remove {d} arguments? ", .{exe_name, filenames.items.len} );
        if(!input_confirmation()){
            return;
        }
    }

    for(filenames.items) |filename| {
        if(is_root(filename)){
            try stdout.print("{s}: it is dangerous to operate recursively on '/'\n", .{exe_name});
            try stdout.print("{s}: use --no-preserve-root to override this failsafe\n", .{exe_name});
        }
        else if(prompt_behavior == .always){
            // TODO - investigate file type (empty file, non-empty, etc) and file permissions
            var filetype = "regular file";
            try stdout.print("{s}: remove {s} '{s}'? ", .{exe_name, filetype, filename} );
            if(!input_confirmation()){
                continue;
            }
        }
        else{
            if(delete_file(filename, cwd)) |status| {
                var filetype = if(status == .dir_deleted) "directory" else "file";
                if(flag_verbose){
                    try stdout.print("{s}: deleted {s} '{s}'\n", .{exe_name, filetype, filename});
                }
            }
            else |err| {
                try report_delete_error(err, filename, exe_name);
            }
        }
        
    }
}