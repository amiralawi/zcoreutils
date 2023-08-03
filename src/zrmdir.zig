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

    const cwd = std.fs.cwd();
    for(args.items[1..]) |dirname| {
        // TODO - handle CLI options
        try cwd.deleteDir(dirname);
    }
}