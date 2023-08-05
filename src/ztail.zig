const generic = @import("./zcorecommon/generic.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");
const stdout = std.io.getStdOut().writer();

const n_lines_max: usize = 10;
var linenumbers: std.ArrayList(usize) = undefined;

pub fn is_valid_option(str: []const u8) bool {
    _ = str;
    return false;
}

pub fn tail_file(file: std.fs.File) !void {
    const readbuffer_size = 2048;
    var readbuffer: [readbuffer_size]u8 = undefined;

    // 3 - read file, find all line numbers & calculate filesize
    // TODO - change this to read backwards starting from EOF
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
        if(linenumbers.items.len < 1 + n_lines_max){
            i_printstart = 0;
        }
        else{
            i_printstart = linenumbers.items[linenumbers.items.len - n_lines_max - 1];
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


const substr = struct{
    str: []const u8 = undefined,
    parent: []const u8 = undefined,
};



const ropestr = struct{
    substrings: std.ArrayList(substr) = undefined,
    alloc: std.mem.allocator = undefined,

    pub fn init(alloc: std.mem.allocator) ropestr{
        return ropestr{
            .alloc = alloc,
            .substrings = std.ArrayList([]const u8).init(alloc),
        };
    }
    pub fn deinit(self: *ropestr) void {
        self.substrings.deinit();
    }
    pub fn append(self: *ropestr, newitem: substr) void {
        self.substrings.append(newitem);
    }
};



pub fn tail_file_kim(file: std.fs.File) !void {
    // TODO - bug when buffer_size = 1
    const buffer_size = 2048;

    const alloc = std.heap.page_allocator;
    
    var lines_buffer_raw = try alloc.alloc(std.ArrayList(substr), n_lines_max);
    defer alloc.free(lines_buffer_raw);

    var linesRing = generic.ringBuffer(std.ArrayList(substr)).init(lines_buffer_raw);

    var line_working: *std.ArrayList(substr) = linesRing.grow().?;
    line_working.* = std.ArrayList(substr).init(alloc);

    var finished = false;
    var istart: usize = undefined;
    var buffer: []u8 = undefined;
    var n_read: usize = undefined;
    var newbytes: []u8 = undefined;
    while(!finished){
        istart = 0;
        buffer = try alloc.alloc(u8, buffer_size);
        n_read = try file.read(buffer);
        newbytes = buffer[0..n_read];

        for(newbytes, 1..) |ch, i| {
            if(ch == '\n' or i == n_read){
                // close the string
                try line_working.append(substr{.str=newbytes[istart..i], .parent=newbytes});
            }
            if(ch == '\n'){
                if(linesRing.isFull()){
                    var overflow = linesRing.read();
                    if(overflow) |popped| {
                        // free overflowed parent buffers if they are not also consumed
                        // by the next item in the ring buffer
                        var next_line = linesRing.peekPtr(0) orelse unreachable;
                        var next_parent = (next_line.*).items[0].parent;

                        for(popped.items) |s|{
                            if(s.parent.ptr == next_parent.ptr){
                                break;
                            }
                            else{
                                alloc.free(s.parent);
                            }
                        }
                    }
                }

                line_working = linesRing.grow().?;
                line_working.* = std.ArrayList(substr).init(alloc);

                istart = i;
            }
        }

        finished = (n_read != buffer_size);
    }

    // handle dangling str
    if(istart != newbytes.len){
        var overflow = linesRing.read();
        if(overflow) |popped| {
            var next_line = linesRing.peekPtr(0) orelse unreachable;
            var next_parent = (next_line.*).items[0].parent;

            // need to free overflow memory
            for(popped.items) |s|{
                if(s.parent.ptr == next_parent.ptr){
                    break;
                }
                else{
                    // free memory
                    alloc.free(s.parent);
                }
            }
        }

    }

    // print to stdout
    var iter = linesRing.peekPtrItems();
    while(iter.next()) |line| {
        for((line.*).items) |str| {
            var s = str.str;
            try stdout.print("{s}", .{s});
        }
    }

    // free memory remaining in the ring buffer
    iter = linesRing.peekPtrItems();
    var last_freed: ?[*]const u8 = null;
    while(iter.next()) |line| {
        for((line.*).items) | str| {
            if(str.parent.ptr != last_freed){
                last_freed = str.parent.ptr;
                alloc.free(str.parent);
            }
        }
    }
}


pub fn tail_file_kim_old(file: std.fs.File) !void {
    // TODO - need to iron out the bug that appears when buffer_size == 1
    const buffer_size = 2048;

    const alloc = std.heap.page_allocator;
    
    var lines_buffer_raw = try alloc.alloc(*std.ArrayList(substr), n_lines_max);
    defer alloc.free(lines_buffer_raw);

    var linesRing = generic.ringBuffer(*std.ArrayList(substr)).init(lines_buffer_raw);

    var line_working = try alloc.create(std.ArrayList(substr));
    line_working.* = std.ArrayList(substr).init(alloc);

    var finished = false;
    var istart: usize = undefined;
    var buffer: []u8 = undefined;
    var n_read: usize = undefined;
    var newbytes: []u8 = undefined;
    while(!finished){
        istart = 0;
        buffer = try alloc.alloc(u8, buffer_size);
        n_read = try file.read(buffer);
        newbytes = buffer[0..n_read];

        for(newbytes, 1..) |ch, i| {
            if(ch == '\n' or i == n_read){
                // close the string
                try line_working.append(substr{.str=newbytes[istart..i], .parent=newbytes});
            }
            if(ch == '\n'){
                var overflow = linesRing.writeForce(line_working);
                //_ = overflow;
                if(overflow) |popped| {
                    var next_line = linesRing.peekPtr(0) orelse unreachable;
                    var next_parent = (next_line.*).items[0].parent;

                    // need to free overflow memory
                    for(popped.items) |s|{
                        if(s.parent.ptr == next_parent.ptr){
                            break;
                        }
                        else{
                            // free memory
                            alloc.free(s.parent);
                        }
                    }
                }

                // make a new line
                line_working = try alloc.create(std.ArrayList(substr));
                line_working.* = std.ArrayList(substr).init(alloc);
                
                istart = i;
            }
        }

        finished = (n_read != buffer_size);
    }

    // handle dangling str
    if(istart != newbytes.len){
        var overflow = linesRing.writeForce(line_working);
        if(overflow) |popped| {
            var next_line = linesRing.peekPtr(0) orelse unreachable;
            var next_parent = (next_line.*).items[0].parent;

            // need to free overflow memory
            for(popped.items) |s|{
                if(s.parent.ptr == next_parent.ptr){
                    break;
                }
                else{
                    // free memory
                    alloc.free(s.parent);
                }
            }
        }
    }

    var iter = linesRing.peekPtrItems();
    while(iter.next()) |line| {
        for((line.*).items) |str| {
            var s = str.str;
            try stdout.print("{s}", .{s});
        }
    }

    // free remaining memory
    iter = linesRing.peekPtrItems();
    var last_freed: ?[*]const u8 = null;
    while(iter.next()) |line| {
        for((line.*).items) | str| {
            if(str.parent.ptr != last_freed){
                last_freed = str.parent.ptr;
                alloc.free(str.parent);
            }
        }
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();



    var args = std.ArrayList([]const u8).init(heapalloc);
    var filenames = std.ArrayList([]const u8).init(heapalloc);
    try cli.args.appendToArrayList(&args, heapalloc);

    //const readbuffer_size = 2048;
    //var readbuffer: [readbuffer_size]u8 = undefined;

    //var linenumbers = std.ArrayList(usize).init(heapalloc);
    linenumbers = std.ArrayList(usize).init(heapalloc);


    // TODO - handle CLI options
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
        // TODO - write function that keeps 10 most recent lines in memory (tail_file_kim)
        //        once stdin stops, print
        //_ = stdin;
        //try tail_file(stdin);
        try tail_file_kim(stdin);
        return;
    }

    var cwd = std.fs.cwd();
    var exe_name = args.items[0];
    for(filenames.items, 0..) |filename, i_file| {
        linenumbers.clearRetainingCapacity();
        

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
        
        // 2 - print filename if we have more than one file
        if(args.items.len > 2){
            var prefix = if(i_file > 0) "\n" else "";
            try stdout.print("{s}==> {s} <==\n", .{prefix, filename});
        }

        try tail_file(file);
    }
}