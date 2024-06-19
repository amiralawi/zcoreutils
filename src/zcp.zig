const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;

const base_exe_name = "zcp";
const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(
        \\Usage: {0s} [OPTION]... [-T] SOURCE DEST
        \\  or:  {0s} [OPTION]... SOURCE... DIRECTORY
        \\  or:  {0s} [OPTION]... -t DIRECTORY SOURCE...
        \\Copy SOURCE to DEST, or multiple SOURCE(s) to DIRECTORY.
        \\
        \\Mandatory arguments to long options are mandatory for short options too.
        \\  -a, --archive                same as -dR --preserve=all
        \\      --attributes-only        don't copy the file data, just the attributes
        \\      --backup[=CONTROL]       make a backup of each existing destination file
        \\  -b                           like --backup but does not accept an argument
        \\      --copy-contents          copy contents of special files when recursive
        \\  -d                           same as --no-dereference --preserve=links
        \\  -f, --force                  if an existing destination file cannot be
        \\                                 opened, remove it and try again (this option
        \\                                 is ignored when the -n option is also used)
        \\  -i, --interactive            prompt before overwrite (overrides a previous -n
        \\                                  option)
        \\  -H                           follow command-line symbolic links in SOURCE
        \\  -l, --link                   hard link files instead of copying
        \\  -L, --dereference            always follow symbolic links in SOURCE
        \\  -n, --no-clobber             do not overwrite an existing file (overrides
        \\                                 a previous -i option)
        \\  -P, --no-dereference         never follow symbolic links in SOURCE
        \\  -p                           same as --preserve=mode,ownership,timestamps
        \\      --preserve[=ATTR_LIST]   preserve the specified attributes (default:
        \\                                 mode,ownership,timestamps), if possible
        \\                                 additional attributes: context, links, xattr,
        \\                                 all
        \\      --no-preserve=ATTR_LIST  don't preserve the specified attributes
        \\      --parents                use full source file name under DIRECTORY
        \\  -R, -r, --recursive          copy directories recursively
        \\      --reflink[=WHEN]         control clone/CoW copies. See below
        \\      --remove-destination     remove each existing destination file before
        \\                                 attempting to open it (contrast with --force)
        \\      --sparse=WHEN            control creation of sparse files. See below
        \\      --strip-trailing-slashes  remove any trailing slashes from each SOURCE
        \\                                 argument
        \\  -s, --symbolic-link          make symbolic links instead of copying
        \\  -S, --suffix=SUFFIX          override the usual backup suffix
        \\  -t, --target-directory=DIRECTORY  copy all SOURCE arguments into DIRECTORY
        \\  -T, --no-target-directory    treat DEST as a normal file
        \\  -u, --update                 copy only when the SOURCE file is newer
        \\                                 than the destination file or when the
        \\                                 destination file is missing
        \\  -v, --verbose                explain what is being done
        \\  -x, --one-file-system        stay on this file system
        \\  -Z                           set SELinux security context of destination
        \\                                 file to default type
        \\      --context[=CTX]          like -Z, or if CTX is specified then set the
        \\                                 SELinux or SMACK security context to CTX
        \\      --help     display this help and exit
        \\      --version  output version information and exit
        \\
        \\By default, sparse SOURCE files are detected by a crude heuristic and the
        \\corresponding DEST file is made sparse as well.  That is the behavior
        \\selected by --sparse=auto.  Specify --sparse=always to create a sparse DEST
        \\file whenever the SOURCE file contains a long enough sequence of zero bytes.
        \\Use --sparse=never to inhibit creation of sparse files.
        \\
        \\When --reflink[=always] is specified, perform a lightweight copy, where the
        \\data blocks are copied only when modified.  If this is not possible the copy
        \\fails, or if --reflink=auto is specified, fall back to a standard copy.
        \\Use --reflink=never to ensure a standard copy is performed.
        \\
        \\The backup suffix is '~', unless set with --suffix or SIMPLE_BACKUP_SUFFIX.
        \\The version control method may be selected via the --backup option or through
        \\the VERSION_CONTROL environment variable.  Here are the values:
        \\
        \\  none, off       never make backups (even if --backup is given)
        \\  numbered, t     make numbered backups
        \\  existing, nil   numbered if numbered backups exist, simple otherwise
        \\  simple, never   always make simple backups
        \\
        \\As a special case, {0s} makes a backup of SOURCE when the force and backup
        \\options are given and SOURCE and DEST are the same name for an existing,
        \\regular file.
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

    const option = str[2..];
    if (util.u8str.cmp(option, "version")) {
        flag_dispVersion = true;
        return true;
    } else if (util.u8str.cmp(option, "help")) {
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
    const exe_name = args.items[0];

    // var options = std.ArrayList([]const u8).init(heapalloc);
    // var filenames = std.ArrayList([]const u8).init(heapalloc);
    // const exe_name = args.items[0];

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

    const filename_dest = filenames[filenames.len - 1];
    const filenames_src = filenames[0 .. filenames.len - 1];

    var dest_dir: std.fs.Dir = undefined;

    const cwd = std.fs.cwd();

    const stat_dest = cwd.statFile(filename_dest);
    if (stat_dest) |s| {
        // file exists - overwrite file into filename_dest
        if (s.kind != .directory and filenames_src.len > 1) {
            try stdout.print("{s}: target '{s}' is not a directory\n", .{ exe_name, filename_dest });
            return EXIT_FAILURE;
        }

        const ddir = std.fs.path.dirname(filename_dest) orelse ".";
        dest_dir = try cwd.openDir(ddir, .{});
    } else |err| {
        switch (err) {
            error.FileNotFound => {
                // copy file into filename_dest
                const ddir = std.fs.path.dirname(filename_dest) orelse ".";
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
        const basename = std.fs.path.basename(filename_src);
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
}
