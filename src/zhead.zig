const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");
const stdout = std.io.getStdOut().writer();

var n_lines_max: usize = 10;

pub fn head_file(file: std.fs.File) !void {
    // 3 - read file, print
    const buffer_size = 2048;
    var buffer: [buffer_size]u8 = undefined;

    var finished = false;
    var lines_printed:usize = 0;
    while(!finished){
        var nread = try file.read(&buffer);
        var readslice = buffer[0..nread];
        

        var print_iend: usize = readslice.len;
        for(readslice, 1..) |ch, i|{
            if(ch == '\n'){
                lines_printed += 1;
                if(lines_printed >= n_lines_max){
                    print_iend = i;
                    break;
                }
            }
        }

        try stdout.print("{s}", .{ buffer[0..print_iend] });
        
        finished = (lines_printed >= n_lines_max) or (nread == 0);
    }
}

pub fn is_valid_option(str: []const u8) bool {
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
    var exe_name = args.items[0];
    
    for(args.items[1..]) |arg| {
        if(is_valid_option(arg)){
            // TODO - handle CLI options
        }
        else{
            try filenames.append(arg);
        }
    }

    if(filenames.items.len == 0){
        // no file argument passed, read standard input instead
        var stdin = std.io.getStdIn();
        try head_file(stdin);
        return;
    }

    var cwd = std.fs.cwd();
    
    for(filenames.items, 0..) |filename, i| {
        // 1 - open file
        var file = cwd.openFile(filename, .{}) catch |err| {
            switch(err){
                std.fs.File.OpenError.FileNotFound => {
                    try stdout.print("{s}: cannot open '{s}' for reading: No such file or directory\n", .{exe_name, filename});
                },
                else => {
                    try stdout.print("{s}: cannot open '{s}' for reading: {any}", .{exe_name, filename, err});
                },
            }
            continue;
        };
        defer file.close();
        
        // 2 - print filename header if we have more than one file
        if(args.items.len > 2){
            var prefix = if(i > 0) "\n" else "";
            try stdout.print("{s}==> {s} <==\n", .{prefix, filename});
        }

        // 3 - print head lines for file
        try head_file(file);
    }
}