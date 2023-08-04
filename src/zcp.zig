const util = @import("./zcorelib/util.zig");
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

pub fn is_valid_option(str: []const u8) bool {
    // TODO: do actual parsing
    _ = str;
    return false;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();


    var args = std.ArrayList([]const u8).init(heapalloc);
    try append_cli_args(&args, heapalloc);

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
        var src = filenames.items[0];
        var dest = filenames.items[1];
        
        // TODO - this does not catch files with different strings that resolve to the same name
        // eg ./a.txt and ./somedir/../a.txt
        if(util.u8str.strcmp(src, dest)){
            try stdout.print("{s}: '{s}' and '{s}' are the same file\n", .{exe_name, src, dest});
            return;
        }

        try cwd.copyFile(src, cwd, dest, .{});
        return;
    }
    
    
    // copy all files to last argument
    var nfiles: usize = filenames.items.len - 1;
    var dest_dirname = filenames.items[nfiles];

    var dest_dir = try cwd.openDir(dest_dirname, .{});
    defer dest_dir.close();

    for(filenames.items[0..nfiles]) |src| {
        var dest = std.fs.path.basename(src);
        try cwd.copyFile(src, dest_dir, dest, .{});
    }

}