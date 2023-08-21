const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;

const base_exe_name = "zwc";
const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(
        \\Usage: {0s} [OPTION]... [FILE]...
        \\  or:  {0s} [OPTION]... --files0-from=F
        \\
    , .{exe_name});
}

const ExpectedOptionValType = enum { none };
var expected_option: ExpectedOptionValType = .none;

var flag_dispHelp = false;
var flag_dispVersion = false;

var ignore_options = false;
pub fn test_option_validity_and_store(str: []const u8) bool {
    if (ignore_options) {
        return false;
    }
    switch (expected_option) {
        .none => {},
    }
    if (std.mem.startsWith(u8, str, "--")) {
        return test_option_validity_and_store(str);
    } else if (std.mem.startsWith(u8, str, "-")) {
        var all_chars_valid_flags = true;
        for (str[1..]) |ch| {
            switch (ch) {
                // 'c', 'm', 'l', 'L', 'w' => {},
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
    if (util.u8str.cmp(str, "--")) {
        ignore_options = true;
        return true;
    }

    var option = str[2..];
    if (util.u8str.cmp(option, "version")) {
        flag_dispVersion = true;
        return true;
    }
    else if (util.u8str.cmp(option, "help")) {
        flag_dispHelp = true;
        return true;
    }
}


pub fn main() !u8 {
    stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();

    var args = std.ArrayList([]const u8).init(heapalloc);
    try cli.args.appendToArrayList(&args, heapalloc);
    var exe_name = args.items[0];

    // var options = std.ArrayList([]const u8).init(heapalloc);
    // var filenames = std.ArrayList([]const u8).init(heapalloc);
    // var exe_name = args.items[0];

    var nfilenames: usize = 0;
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
    var filenames = args.items[0..nfilenames];

    if (filenames.len == 0) {
        try stdout.print("{s}: missing file operand\n", .{exe_name});
        try stdout.print("Try '{s} --help' for more information.\n", .{exe_name});
        return EXIT_FAILURE;
    } else if (filenames.len == 1) {
        try stdout.print("{s}: missing destination file operand after '{s}'\n", .{ exe_name, filenames[0] });
        try stdout.print("Try '{s} --help' for more information.\n", .{exe_name});
        return EXIT_FAILURE;
    }

    var filename_dest = filenames[filenames.len - 1];
    const filenames_src = filenames[0 .. filenames.len - 1];

    var dest_dir: std.fs.Dir = undefined;

    const cwd = std.fs.cwd();

    var stat_dest = cwd.statFile(filename_dest);
    if (stat_dest) |s| {
        // file exists - overwrite file into filename_dest
        if (s.kind != .directory and filenames_src.len > 1) {
            try stdout.print("{s}: target '{s}' is not a directory\n", .{ exe_name, filename_dest });
            return EXIT_FAILURE;
        }

        var ddir = std.fs.path.dirname(filename_dest) orelse ".";
        dest_dir = try cwd.openDir(ddir, .{});
    } else |err| {
        switch (err) {
            error.FileNotFound => {
                // copy file into filename_dest
                var ddir = std.fs.path.dirname(filename_dest) orelse ".";
                dest_dir = try cwd.openDir(ddir, .{});
            },
            error.IsDir => {
                // copy file into filename_dest/filename_src
                dest_dir = try cwd.openDir(filename_dest, .{});
            },
            else => {
                return err;
            },
        }
    }
    defer dest_dir.close();

    for (filenames_src) |filename_src| {
        var basename = std.fs.path.basename(filename_src);
        cwd.copyFile(filename_src, dest_dir, basename, .{}) catch |err| {
            switch (err) {
                error.IsDir => {
                    try stdout.print("trying to copy a directory '{s}' - TODO -> check if flag exists\n", .{basename});
                },
                else => {},
            }
        };
    }

    return EXIT_SUCCESS;
    // var retain_filename = true;

    // if (filenames_src.len == 1) {
    //     var ddir = cwd.openDir(std.fs.path.dirname(filename_dest).?, .{});
    //     if (ddir) |d| {
    //         dest_dir = d;
    //     } else |err| {
    //         switch (err) {
    //             error.NotDir => {
    //                 // replace existing file
    //                 filename_dest = std.fs.path.dirname(filename_dest).?;
    //                 retain_filename = false;
    //             },
    //             else => {
    //                 return err;
    //             },
    //         }
    //     }
    // } else {
    //     // multiple source files
    //     var ddir = cwd.openDir(std.fs.path.dirname(filename_dest).?, .{});
    //     if(ddir) |d| {
    //         dest_dir = d;
    //     }
    //     else |err|{
    //         switch (err) {
    //             error.NotDir => {
    //                 try stdout.print("{s}: target '{s}' is not a directory", .{ exe_name, filename_dest });
    //             },
    //             else => {
    //                 return err;
    //             },
    //         }
    //     }

    //     retain_filename = true;
    // }
    // defer dest_dir.close();

    // for (filenames_src) |filename_src| {
    //     var dest_filename = if (retain_filename) std.fs.path.basename(filename_src) else filename_dest;
    //     try cwd.copyFile(filename_src, dest_dir, dest_filename, .{});
    // }
    // return EXIT_SUCCESS;

    // // else if (filenames.items.len == 2) {
    // //     var src = filenames.items[0];
    // //     var dest = filenames.items[1];

    // //     // TODO - this does not catch files with different strings that resolve to the same name
    // //     // eg ./a.txt and ./somedir/../a.txt
    // //     if (util.u8str.cmp(src, dest)) {
    // //         try stdout.print("{s}: '{s}' and '{s}' are the same file\n", .{ exe_name, src, dest });
    // //         return;
    // //     }

    // //     try cwd.copyFile(src, cwd, dest, .{});
    // //     return;
    // // }

    // // // copy all files to last argument
    // // var nfiles: usize = filenames.items.len - 1;
    // // var dest_dirname = filenames.items[nfiles];

    // // var dest_dir = try cwd.openDir(dest_dirname, .{});
    // // defer dest_dir.close();

    // // for (filenames.items[0..nfiles]) |src| {
    // //     var dest = std.fs.path.basename(src);
    // //     try cwd.copyFile(src, dest_dir, dest, .{});
    // // }

}
