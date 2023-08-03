const util = @import("./util.zig");
const std = @import("std");
const stdout = std.io.getStdOut().writer();

fn append_cli_args(container: *std.ArrayList([]const u8), allocator: std.mem.Allocator) !void {
    var argiter = try std.process.argsWithAllocator(allocator);
    while (argiter.next()) |arg| {
        try container.append(arg);
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();


    const n_lines_max: usize = 10;
    const readbuffer_size = 2048;


    var args = std.ArrayList([]const u8).init(heapalloc);
    try append_cli_args(&args, heapalloc);

    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var readbuffer: [readbuffer_size]u8 = undefined;

    var linenumbers = std.ArrayList(usize).init(heapalloc);


    var exe_name = args.items[0];
    for(args.items[1..], 0..) |filename, i_file| {
        linenumbers.clearRetainingCapacity();
        // TODO - handle CLI options

        // 1 - open file
        var pathstr = std.fs.realpath(filename, &path_buffer) catch |err| {
            try stdout.print("{s}: cannot open '{s}' for reading: {any}\n", .{exe_name, filename, err});
            continue;
        };

        var file = std.fs.openFileAbsolute(pathstr, .{}) catch |err|{
            try stdout.print("{s}: cannot open '{s}' for reading: {any}\n", .{exe_name, filename, err});
            continue;
        };
        defer file.close();
        
        // 2 - print filename if we have more than one file
        if(args.items.len > 2){
            var prefix = if(i_file > 0) "\n" else "";
            try stdout.print("{s}==> {s} <==\n", .{prefix, filename});
        }

        // 3 - read file, find all line numbers & calculate filesize
        var i_ch: usize = 0;
        var finished = false;
        var filesize: usize = 0;
        while(!finished){
            var nread = try file.read(&readbuffer);
            var readslice = readbuffer[0..nread];
            for(readslice) |ch|{
                if(ch == '\n') {
                    try linenumbers.append(i_ch);
                }
                i_ch += 1;
            }
            filesize += nread;
            finished = (nread == 0);
        }

        // 4 - calculate file location to start printing from
        var i_printstart: usize = 0;
        if(linenumbers.items.len != 0){
            var j = linenumbers.items.len - n_lines_max - 1;
            if(j < 0){
                i_printstart = 0;
            }
            else{
                i_printstart = linenumbers.items[j];
                // i_printstart points to the nth last '\n' -> this character is technically the end of the 
                // preceding line and should not be printed.  Need to increment i_printstart, but also need
                // to guard against edge-case where the last character in file is also '\n' and nlines = 1
                i_printstart = @min((i_printstart + 1), filesize - 1);
            }
        }

        // 4 - reread file from start index and print
        try file.seekTo(i_printstart);
        finished = false;
        while(!finished){
            var nread = try file.read(&readbuffer);
            var readslice = readbuffer[0..nread];
            try stdout.print("{s}", .{readslice});
            finished = (nread == 0);
        }
    }
}