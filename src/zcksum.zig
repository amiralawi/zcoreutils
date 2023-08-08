const library = @import("./zcorecommon/library.zig");
const cli = @import("./zcorecommon/cli.zig");
const util = @import("./zcorecommon/util.zig");
const std = @import("std");
const stdout = std.io.getStdOut().writer();

pub fn print_usage() !void{
    try stdout.print("Usage: cksum [FILE]...\n", .{});
    try stdout.print("  or:  cksum [OPTION]\n", .{});
    try stdout.print("Print CRC checksum, bytecount, and filename of each FILE.  Standard\n", .{});
    try stdout.print("input will be used if no FILE is specified.\n", .{});
}

pub fn print_version() !void{
    try stdout.print("zcksum ({s}) {s}\n", .{library.name, library.version});
    try stdout.print("Copyright (C) {s} Amir Alawi.\n", .{library.copyright_year});
    try stdout.print("License: {s}.\n\n", .{library.license_short});
    try stdout.print("Written by Amir Alawi.\n", .{});
}


const crcHashResult = struct{
    nbytes: usize = 0,
    hash: u32 = 0,
};

pub fn hash_file(file: std.fs.File) !crcHashResult {
    // TODO - consider moving buffer into global variable scope
    //        this will alloc utility to be compiled w/small stack requirments
    const readbuffer_size = 2048;
    var readbuffer: [readbuffer_size]u8 = undefined;
    var crc = std.hash.crc.Crc32Cksum.init();

    // read file in chunks & hash to preserve memory
    var n_tot: usize = 0;
    var finished: bool = false;
    while(!finished){
        var nread = try file.read(&readbuffer);
        var readslice = readbuffer[0..nread];
        crc.update(readslice);

        n_tot += nread;

        finished = (nread == 0);
    }
    
    // append the byte-count in little-endian format, discard trailing zero bytes
    var nread_le = std.mem.nativeToLittle(usize, n_tot);
    var nread_le_bytearr: [@sizeOf(usize)]u8 = @bitCast(nread_le);
    //var nread_le_bytearr = @bitCast([@sizeOf(usize)]u8, nread_le);
    var j: usize  = @sizeOf(usize) - 1;
    while(j > 0 and nread_le_bytearr[j] == 0){
        j -= 1;
    }
    crc.update(nread_le_bytearr[0..j+1]);

    return crcHashResult{.nbytes=n_tot, .hash=crc.final()};
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();


    var args = std.ArrayList([]const u8).init(heapalloc);
    try cli.args.appendToArrayList(&args, heapalloc);
    
    var exe_name = args.items[0];
    if(args.items.len == 1){
        // no arguments supplied - perform CRC on standard input
        var stdin = std.io.getStdIn();
        var res = try hash_file(stdin);
        try stdout.print("{d} {d}\n", .{res.hash, res.nbytes});
        return;
    }
    else if(args.items.len == 2){
        if(util.u8str.strcmp(args.items[1], "--help")){
            try print_usage();
            return;
        }
        else if(util.u8str.strcmp(args.items[1], "--version")){
            try print_version();
            return;
        }
    }

    var cwd = std.fs.cwd();
    for(args.items[1..]) |filename| {
        var file = cwd.openFile(filename, .{}) catch |err| {
            switch(err){
                std.fs.File.OpenError.FileNotFound => {
                    try stdout.print("{s}: {s}: No such file or directory\n", .{exe_name, filename});
                },
                else => {
                    try stdout.print("{s}: {s}: {any}\n", .{exe_name, filename, err});
                },
            }
            continue;
        };
        defer file.close();

        var res = try hash_file(file);
        try stdout.print("{d} {d} {s}\n", .{res.hash, res.nbytes, filename});
    }
}