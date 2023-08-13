const library = @import("./zcorecommon/library.zig");
const cli = @import("./zcorecommon/cli.zig");
const util = @import("./zcorecommon/util.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;

const base_exe_name = "zcksum";

pub fn print_usage(exe_name: []const u8) !void{
    try stdout.print(
        \\Usage: {0s} [FILE]...
        \\  or:  {0s} [OPTION]
        \\Print CRC checksum, bytecount, and filename of each FILE.  Standard
        \\input will be used if no FILE is specified.
        \\
        \\      --help     display this help and exit
        \\      --version  output version information and exit
        \\
        , .{exe_name}
    );
}

const crcHashResult = struct{
    nbytes: usize = 0,
    hash: u32 = 0,
};

pub fn hash_file(file: std.fs.File) !crcHashResult {
    // TODO - consider moving buffer into global variable scope
    //        this will allow utility to be compiled w/small stack requirments
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
    var j: usize  = @sizeOf(usize) - 1;
    while(j > 0 and nread_le_bytearr[j] == 0){
        j -= 1;
    }
    crc.update(nread_le_bytearr[0..j+1]);

    return crcHashResult{.nbytes=n_tot, .hash=crc.final()};
}

pub fn report_cksum_error(err: anyerror, filename: []const u8, exe_name: []const u8) !void {
    switch(err){
        std.fs.File.OpenError.FileNotFound => {
            try stderr.print("{s}: {s}: No such file or directory\n", .{exe_name, filename});
        },
        error.IsDir => {
            try stderr.print("{s}: {s}: Is a directory\n", .{exe_name, filename});
        },
        error.AccessDenied => {
            try stderr.print("{s}: {s}: Permission denied\n", .{exe_name, filename});
        },
        else => {
            try stderr.print("{s}: {s}: unrecognized error '{any}'\n", .{exe_name, filename, err});
        },
    }
}

pub fn main() !void {
    stdout = std.io.getStdOut().writer();
    stderr = std.io.getStdErr().writer();

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
        if(util.u8str.cmp(args.items[1], "--help")){
            try print_usage(exe_name);
            return;
        }
        else if(util.u8str.cmp(args.items[1], "--version")){
            try library.print_exe_version(stdout, base_exe_name);
            return;
        }
    }

    var cwd = std.fs.cwd();
    for(args.items[1..]) |filename| {
        var file = cwd.openFile(filename, .{}) catch |err| {
            try report_cksum_error(err, filename, exe_name);
            continue;
        };
        defer file.close();

        var res = try hash_file(file);
        try stdout.print("{d} {d} {s}\n", .{res.hash, res.nbytes, filename});
    }
}