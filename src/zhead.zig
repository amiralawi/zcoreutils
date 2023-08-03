const util = @import("./util.zig");
const std = @import("std");
const stdout = std.io.getStdOut().writer();

fn append_cli_args(container: *std.ArrayList([]const u8), allocator: std.mem.Allocator) !void {
    var argiter = try std.process.argsWithAllocator(allocator);
    while (argiter.next()) |arg| {
        try container.append(arg);
    }
}


var n_printed:usize = 0;
pub fn counter_reset() void {
    n_printed = 0;
}

pub fn print_until_nch(buffer: []const u8, n: usize, ch: u8) !bool {
    var i: usize = 0;
    while(i < buffer.len and n_printed < n){
        if(buffer[i] == ch){
            n_printed += 1;
        }
        i += 1;
    }

    try stdout.print("{s}", .{ buffer[0..i] });

    return n < n_printed;

}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();


    var args = std.ArrayList([]const u8).init(heapalloc);
    try append_cli_args(&args, heapalloc);

    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;

    var n_lines_max: usize = 10;
    const readbuffer_size = 2048;
    var readbuffer: [readbuffer_size]u8 = undefined;


    var exe_name = args.items[0];
    for(args.items[1..], 0..) |filename, i| {
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
            var prefix = if(i > 0) "\n" else "";
            try stdout.print("{s}==> {s} <==\n", .{prefix, filename});
        }

        // 3 - read file, print
        var finished = false;
        while(!finished){
            var nread = try file.read(&readbuffer);
            var readslice = readbuffer[0..nread];

            var n_complete = try print_until_nch(readslice, n_lines_max, '\n');
            finished = n_complete or nread == 0;
        }
        counter_reset();
    }
}