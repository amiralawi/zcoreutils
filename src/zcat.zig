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


    var args = std.ArrayList([]const u8).init(heapalloc);
    try append_cli_args(&args, heapalloc);

    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;

    const readbuffer_size = 2048;
    var readbuffer: [readbuffer_size]u8 = undefined;


    var exe_name = args.items[0];
    for(args.items[1..]) |filename| {
        // TODO - handle CLI options

        // 1 - open file
        var pathstr = std.fs.realpath(filename, &path_buffer) catch |err| {
            switch(err){
                std.os.RealPathError.FileNotFound => {
                    try stdout.print("{s}: {s}: No such file or directory\n", .{exe_name, filename});
                },
                else => {
                    try stdout.print("{s}: {s}: {any}\n", .{exe_name, filename, err});
                }
            }
            continue;
        };

        var file = std.fs.openFileAbsolute(pathstr, .{}) catch |err|{
            switch(err){
                std.fs.File.OpenError.FileNotFound => {
                    try stdout.print("{s}: {s}: No such file or directory\n", .{exe_name, filename});
                },
                else => {
                    try stdout.print("{s}: {s}: {any}\n", .{exe_name, filename, err});
                }
            }
            continue;
        };
        defer file.close();
        

        // 2 - read file & print
        var finished = false;
        while(!finished){
            var nread = try file.read(&readbuffer);
            var readslice = readbuffer[0..nread];
            try stdout.print("{s}", .{ readslice });

            finished = (nread == 0);
        }
    }
}