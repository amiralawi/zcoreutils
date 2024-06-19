const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");
const za = @import("zargh");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;
var stdin: std.fs.File.Reader = undefined;

const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;

const PromptType = enum { always, once, never };

pub fn input_confirmation() bool {
    var b = [1]u8{0};
    var nread = stdin.read(&b) catch {
        return false;
    };
    const val = (b[0] == 'Y') or (b[0] == 'y');

    // read to EOL
    while (nread != 0 and b[0] != '\n') {
        nread = stdin.read(&b) catch 0;
    }
    return val;
}

pub fn delete_file(filename: []const u8, cwd: std.fs.Dir, recursive: bool, emptydir: bool) !file_type {
    if (cwd.deleteFile(filename)) {
        return file_type.file;
    } else |errFile| {
        if (errFile == error.IsDir) {
            if (recursive) {
                if (cwd.deleteTree(filename)) {
                    return file_type.dir;
                } else |errTree| {
                    return errTree;
                }
            } else if (emptydir) {
                if (cwd.deleteDir(filename)) {
                    return file_type.dir;
                } else |errDir| {
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
    switch (err) {
        error.FileNotFound => {
            try stderr.print("{s}: cannot remove '{s}': No such file or directory\n", .{ exe_name, filename });
        },
        error.IsDir => {
            try stderr.print("{s}: cannot remove '{s}': Is a directory\n", .{ exe_name, filename });
        },
        error.AccessDenied => {
            try stderr.print("{s}: cannot remove '{s}': Permission denied\n", .{ exe_name, filename });
        },
        error.DirNotEmpty => {
            try stderr.print("{s}: cannot remove '{s}': Directory not empty\n", .{ exe_name, filename });
        },
        else => {
            try stderr.print("{s}: cannot remove '{s}': unrecognized error '{any}'\n", .{ exe_name, filename, err });
        },
    }
}

const file_type = enum { file, dir };

pub const zrmContext = struct {
    const Self = @This();
    const base_exe_name = "zrm";

    promptBehavior: PromptType = .never,
    exe_name: []const u8 = Self.base_exe_name,

    help: za.Option = .{
        .long = "help",
        .help = "display this help and exit",
        .action = dispUsage,
    },
    version: za.Option = .{
        .long = "version",
        .help = "output version information and exit",
        .action = dispVersion,
    },
    force: za.Option = .{
        .short = 'f',
        .long = "force",
        .help = "ignore nonexistent files and arguments, never prompt",
        .action = setForce,
    },
    i: za.Option = .{
        .short = 'i',
        .help = "prompt before every removal",
        .action = setPromptAlways,
    },
    I: za.Option = .{
        .short = 'I',
        .help = "prompt once before removing more than three files.  Less intrusive than -i, while still giving protection against most mistakes",
        .action = setPromptOnce,
    },
    interactive: za.Option = .{
        .long = "interactive",
        .help = "Prompt according to optional supplied parameter: never, once, or always.",
        .argument = .optional,
        .action = null,
    },
    recursive: za.Option = .{
        .short = 'r',
        .long = "recursive",
        .help = "remove directories and their contents recursively",
        .action = setRecursive,
    },
    recursive2: za.Option = .{
        .short = 'R',
        .help = "alias for -r",
        .action = setRecursive,
    },
    emptydir: za.Option = .{
        .short = 'd',
        .long = "dir",
        .help = "remove empty directories",
        .action = null,
    },
    verbose: za.Option = .{
        .short = 'v',
        .long = "verbose",
        .help = "explain what is being done",
        .action = za.Option.Actions.flagTrue,
    },
    preserveRoot: za.Option = .{
        .long = "preserve-root",
        .help = "do not remove '/' (default);  with 'all', reject any command line argument on a separate device from its parentexplain what is being done",
        .argument = .optional,
        .action = setPreserveRoot,
        .flag = true,
    },
    noPreserveRoot: za.Option = .{
        .long = "no-preserve-root",
        .help = "do not treat '/' specially",
        .action = setNoPreserveRoot,
    },

    pub fn setNoPreserveRoot(ctx: *anyopaque, opt: *za.Option) void {
        _ = opt;
        var zrm: *zrmContext = @alignCast(@ptrCast(ctx));
        zrm.noPreserveRoot.flag = true;
        zrm.preserveRoot.flag = false;
    }

    pub fn setPreserveRoot(ctx: *anyopaque, opt: *za.Option) void {
        _ = opt;
        var zrm: *zrmContext = @alignCast(@ptrCast(ctx));
        zrm.preserveRoot.flag = true;
        zrm.noPreserveRoot.flag = false;
    }

    pub fn setRecursive(ctx: *anyopaque, opt: *za.Option) void {
        _ = opt;
        var zrm: *zrmContext = @alignCast(@ptrCast(ctx));
        zrm.recursive.flag = true;
    }

    pub fn setPromptAlways(ctx: *anyopaque, opt: *za.Option) void {
        _ = opt;
        var zrm: *zrmContext = @alignCast(@ptrCast(ctx));
        zrm.promptBehavior = .always;
        zrm.force.flag = false;
    }
    pub fn setPromptOnce(ctx: *anyopaque, opt: *za.Option) void {
        _ = opt;
        var zrm: *zrmContext = @alignCast(@ptrCast(ctx));
        zrm.promptBehavior = .always;
        zrm.force.flag = false;
    }
    pub fn setForce(ctx: *anyopaque, opt: *za.Option) void {
        _ = opt;
        var zrm: *zrmContext = @alignCast(@ptrCast(ctx));
        zrm.promptBehavior = .always;
        zrm.force.flag = true;
    }

    pub fn dispUsage(ctx: *anyopaque, opt: *za.Option) void {
        _ = opt;
        const c: *zrmContext = @alignCast(@ptrCast(ctx));
        stdout.print(
            \\Usage: {0s} [OPTION]... [FILE]...
            \\Remove (unlink) the FILE(s).
            \\
            \\CURRENTLY SUPPORTED OPTIONS
            \\
        , .{c.exe_name}) catch {};
        stdout.print("{s}\r\n", .{za.Parser(Self).helpstr}) catch {};
        stdout.print(
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
        , .{ c.exe_name, Self.base_exe_name }) catch {};
    }
    pub fn dispVersion(ctx: *anyopaque, opt: *za.Option) void {
        _ = ctx;
        _ = opt;
        stdout.print("version=xxx\r\n", .{}) catch {};
    }
};

pub fn main() !u8 {
    stdout = std.io.getStdOut().writer();
    stderr = std.io.getStdErr().writer();
    stdin = std.io.getStdIn().reader();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();

    var args = try za.getArgs(heapalloc);

    var ctx = zrmContext{};
    var parser = za.Parser(zrmContext).init(&ctx);
    ctx.exe_name = args.items[0];

    // process options & update globals
    const cwd = std.fs.cwd();
    var nfilenames: usize = 0;
    for (args.items[1..]) |arg| {
        // Move anything that isn't a valid option to the beginning of args - take the bottom
        // slice for use as filenames later

        if (parser.parse(arg)) |validOption| {
            if (!validOption) {
                args.items[nfilenames] = arg;
                nfilenames += 1;
            }
        } else |err| switch (err) {
            error.InvalidLongOption => {
                try stderr.print("{s}: invalid long option '{s}'\r\n", .{ ctx.exe_name, arg });
                return EXIT_FAILURE;
            },
            error.InvalidShortOption => {
                try stderr.print("{s}: invalid short option '{s}'\r\n", .{ ctx.exe_name, arg });
                return EXIT_FAILURE;
            },
            error.UnexpectedArgument => {
                try stderr.print("{s}: option '{s}' has unexpected argument\r\n", .{ ctx.exe_name, arg });
                return EXIT_FAILURE;
            },
        }

        // these two always exit immediately
        if (ctx.help.flag) {
            return EXIT_SUCCESS;
        }
        if (ctx.version.flag) {
            return EXIT_SUCCESS;
        }
    }
    const filenames = args.items[0..nfilenames];

    if (ctx.promptBehavior == .once and filenames.len > 3) {
        try stdout.print("{s}: remove {d} arguments? ", .{ ctx.exe_name, filenames.len });
        if (!input_confirmation()) {
            return EXIT_SUCCESS;
        }
    }

    for (filenames) |filename| {
        var confirm_deletion = true;
        var filetype: []const u8 = "";

        if (is_root(filename)) {
            try stderr.print("{s}: it is dangerous to operate recursively on '/'\n", .{ctx.exe_name});
            try stderr.print("{s}: use --no-preserve-root to override this failsafe\n", .{ctx.exe_name});
            confirm_deletion = ctx.noPreserveRoot.flag;
        } else if (ctx.promptBehavior == .always) {
            // TODO - investigate file type (empty file, non-empty, etc) and file permissions
            // filetype = "empty file", "regular file", "directory" or "empty directory"
            try stdout.print("{s}: remove {s} '{s}'? ", .{ ctx.exe_name, filetype, filename });
            confirm_deletion = input_confirmation();
        }

        if (!confirm_deletion) {
            continue;
        }

        if (delete_file(filename, cwd, ctx.recursive.flag, ctx.emptydir.flag)) |status| {
            filetype = if (status == .dir) "directory " else "file ";
            if (ctx.verbose.flag) {
                try stdout.print("{s}: deleted {s}'{s}'\n", .{ ctx.exe_name, filetype, filename });
            }
        } else |err| {
            try report_delete_error(err, filename, ctx.exe_name);
        }
    }
    return EXIT_SUCCESS;
}
