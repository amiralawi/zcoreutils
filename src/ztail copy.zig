const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");
const stdout = std.io.getStdOut().writer();

var n_lines_max: usize = 10;
var linenumbers: std.ArrayList(usize) = undefined;

pub fn tail_file(file: std.fs.File) !void {
    const readbuffer_size = 2048;
    var readbuffer: [readbuffer_size]u8 = undefined;

    // 1 - read file, find all line numbers & calculate filesize
    // TODO - change this to read backwards starting from EOF
    var i_ch: usize = 0;
    var finished = false;
    var filesize: usize = 0;
    while (!finished) {
        const nread = try file.read(&readbuffer);
        const readslice = readbuffer[0..nread];
        for (readslice) |ch| {
            if (ch == '\n') {
                try linenumbers.append(i_ch);
            }
            i_ch += 1;
        }
        filesize += nread;
        finished = (nread == 0);
    }

    // 2 - calculate file location to start printing from
    var i_printstart: usize = 0;
    if (linenumbers.items.len != 0) {
        if (linenumbers.items.len < 1 + n_lines_max) {
            i_printstart = 0;
        } else {
            i_printstart = linenumbers.items[linenumbers.items.len - n_lines_max - 1];
            // i_printstart points to the nth last '\n' -> this character is technically the end of the
            // preceding line and should not be printed.  Need to increment i_printstart, but also need
            // to guard against edge-case where the last character in file is also '\n' and nlines = 1
            i_printstart = @min((i_printstart + 1), filesize - 1);
        }
    }

    // 3 - reread file from start index and print
    try file.seekTo(i_printstart);
    finished = false;
    while (!finished) {
        const nread = try file.read(&readbuffer);
        const readslice = readbuffer[0..nread];
        try stdout.print("{s}", .{readslice});
        finished = (nread == 0);
    }
}

pub fn is_valid_option(str: []const u8) bool {
    // TODO - handle CLI options
    _ = str;
    return false;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();

    var args = std.ArrayList([]const u8).init(heapalloc);
    var filenames = std.ArrayList([]const u8).init(heapalloc);
    try cli.args.appendToArrayList(&args, heapalloc);

    linenumbers = std.ArrayList(usize).init(heapalloc);

    const exe_name = args.items[0];

    for (args.items) |arg| {
        if (is_valid_option(arg)) {
            // TODO - handle CLI options
        } else {
            try filenames.append(arg);
        }
    }

    if (filenames.items.len == 0) {
        // no file argument passed, read standard input instead
        const stdin = std.io.getStdIn();
        try tail_file(stdin);
        return;
    }

    var cwd = std.fs.cwd();

    for (filenames.items, 0..) |filename, i_file| {
        linenumbers.clearRetainingCapacity();

        // open file & error checking
        var file = cwd.openFile(filename, .{}) catch |err| {
            switch (err) {
                std.fs.File.OpenError.FileNotFound => {
                    try stdout.print("{s}: cannot open '{s}' for reading: No such file or directory\n", .{ exe_name, filename });
                },
                else => {
                    try stdout.print("{s}: cannot open '{s}' for reading: {any}", .{ exe_name, filename, err });
                },
            }
            continue;
        };
        defer file.close();

        // print filename header if we have more than one file
        if (args.items.len > 2) {
            const prefix = if (i_file > 0) "\n" else "";
            try stdout.print("{s}==> {s} <==\n", .{ prefix, filename });
        }

        try tail_file(file);
    }
}
