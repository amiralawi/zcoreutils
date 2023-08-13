const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;

pub fn is_valid_option(str: []const u8) bool {
    // TODO: do actual parsing
    _ = str;
    return false;
}

pub fn main() !void {
    stdout = std.io.getStdOut().writer();
    
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();

    var args = std.ArrayList([]const u8).init(heapalloc);
    try cli.args.appendToArrayList(&args, heapalloc);

    var options = std.ArrayList([]const u8).init(heapalloc);
    var filenames = std.ArrayList([]const u8).init(heapalloc);
    var exe_name = args.items[0];

    for(args.items[1..]) |arg| {
        if(is_valid_option(arg)){
            try options.append(arg);
        }
        else{
            try filenames.append(arg);
        }
    }

    // TODO - read through options

    const cwd = std.fs.cwd();
    if(filenames.items.len == 1){
        try stdout.print("{s}: missing destination file operand after '{s}'\n", .{exe_name, filenames.items[0]});
        try stdout.print("Try '{s} --help' for more information.\n", .{exe_name});
        return;
    }
    else if(filenames.items.len == 2){
        // copy file filenames[0] to filenames[b]
        var src = filenames.items[0];
        var dest = filenames.items[1];

        // TODO - this does not catch files with different strings that resolve to the same name
        // eg ./a.txt and ./somedir/../a.txt
        if(util.u8str.cmp(src, dest)){
            try stdout.print("{s}: '{s}' and '{s}' are the same file\n", .{exe_name, src, dest});
            return;
        }
        
        try cwd.rename(src, dest);
        return;
    }
    
    // move all files to directory specified in last argument
    var nfiles: usize = filenames.items.len - 1;
    var dest_dirname = filenames.items[nfiles];

    var dest_dir = try cwd.openDir(dest_dirname, .{});
    defer dest_dir.close();

    for(filenames.items[0..nfiles]) |src| {
        var filename = std.fs.path.basename(src);
        var dest_parts = [2][]const u8{dest_dirname, filename};
        var dest = try std.fs.path.join(heapalloc, &dest_parts);

        try cwd.rename(src, dest);
    }

}