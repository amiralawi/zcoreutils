const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");
const stdout = std.io.getStdOut().writer();





pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();


    var args = std.ArrayList([]const u8).init(heapalloc);
    try cli.args.appendToArrayList(&args, heapalloc);

    const cwd = std.fs.cwd();
    for(args.items[1..]) |filename| {
        // TODO - handle CLI options
    
        var file = try cwd.createFile(filename, .{ .truncate = false });
        defer file.close();
    }
}