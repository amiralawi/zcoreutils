const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

const assert = std.debug.assert;

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;


const base_exe_name = "zbase64";
const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;
const buffer_size = 1024;



pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(

        \\Usage: {0s} [OPTION]... [FILE]
        \\Base64 encode or decode FILE, or standard input, to standard output.
        \\
        \\With no FILE, or when FILE is -, read standard input.
        \\
        \\Mandatory arguments to long options are mandatory for short options too.
        \\  -d, --decode          decode data
        \\  -i, --ignore-garbage  when decoding, ignore non-alphabet characters
        \\  -w, --wrap=COLS       wrap encoded lines after COLS character (default 76).
        \\                          Use 0 to disable line wrapping
        \\
        \\      --help     display this help and exit
        \\      --version  output version information and exit
        \\
        \\The data are encoded as described for the base64 alphabet in RFC 4648.
        \\When decoding, the input may contain newlines in addition to the bytes of
        \\the formal base64 alphabet.  Use --ignore-garbage to attempt to recover
        \\from any other non-alphabet bytes in the encoded stream.
        \\
        , .{ exe_name}
    );
}

const ExpectedOptionValType = enum { none, wrapcols };
var expected_option: ExpectedOptionValType = .none;

var flag_dispVersion = false;
var flag_dispHelp = false;

var flag_decode = false;
var flag_ignore_garbage = false;
var wrap_cols:usize = 76;


var ignore_options = false;
pub fn test_option_validity_and_store(str: []const u8) !bool {
    if(ignore_options){
        return false;
    }
    else if(expected_option != .none){
        switch(expected_option){
            .none => {},
            .wrapcols => { wrap_cols = try std.fmt.parseInt(usize, str, 10); },
        }
        expected_option = .none;
        return true;
    }
    else if(std.mem.startsWith(u8, str, "--")){
        return try test_long_option_validity_and_store(str);
    }
    else if(std.mem.startsWith(u8, str, "-") and str.len > 1){
        var all_chars_valid_flags = true;
        for(str[1..]) |ch| {
            switch(ch){
                'd', 'i', 'w' => {},
                else => { all_chars_valid_flags = false; },
            }
        }

        if(!all_chars_valid_flags){
            return false;
        }

        for(str[1..]) |ch| {
            switch(ch){
                'd' => { flag_decode = true; },
                'i' => { flag_ignore_garbage = true; },
                'w' => { expected_option = .wrapcols; },
                else => unreachable,
            }
        }
        return true;
    }
    return false;
}

pub fn test_long_option_validity_and_store(str: []const u8) !bool {
    // this function only gets called when str starts with "--"
    if(std.mem.eql(u8, str, "--")){
        ignore_options = true;
        return true;
    }

    const option = str[2..];
    if(std.mem.eql(u8, option, "version")){
        flag_dispVersion = true;
        return true;
    }
    else if(std.mem.eql(u8, option, "help")){
        flag_dispHelp = true;
        return true;
    }
    else if(std.mem.eql(u8, option, "decode")){
        flag_decode = true;
        return true;
    }
    else if(std.mem.eql(u8, option, "ignore-garbage")){
        flag_ignore_garbage = true;
        return true;
    }
    else if(std.mem.startsWith(u8, option, "wrap=")){
        // TODO
        return true;
    }

    return false;
}


pub fn report_fileopen_error(err: anyerror, filename: []const u8, exe_name: []const u8) !void {
    switch(err){          
        error.FileNotFound =>{
            // TODO - pretty sure this doesn't occur
            try stderr.print("{s}: '{s}': No such file or directory\n", .{exe_name, filename});
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



pub const b64Codec = struct {
    alphabet_chars: [64]u8 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".*,
    pad_char: ?u8 = '=',
    acc: u12 = 0,
    acc_len: u4 = 0,
    n_enc: usize = 0,


    /// dest.len must at least be what you get from ::calcSize.
    pub fn encodeBatch(self: *b64Codec, dest: []u8, source: []const u8) []const u8 {
        //const out_len = encoder.calcSize(source.len);
        //assert(dest.len >= out_len);

        var out_idx: usize = 0;
        for (source) |v| {
            self.acc = (self.acc << 8) + v;
            self.acc_len += 8;
            while (self.acc_len >= 6) {
                self.acc_len -= 6;
                dest[out_idx] = self.alphabet_chars[@as(u6, @truncate((self.acc >> self.acc_len)))];
                out_idx += 1;
            }
        }
        self.n_enc += out_idx;
        return dest[0..out_idx];
    }
    pub fn encodeDanglers(self: *b64Codec, dest: []u8) []const u8 {
        if(self.acc_len == 0){
            return dest[0..0];
        }

        var out_idx: usize = 0;
        if (self.acc_len > 0) {
            dest[out_idx] = self.alphabet_chars[@as(u6, @truncate((self.acc << 6 - self.acc_len)))];
            out_idx += 1;
        }
        self.n_enc += out_idx;
        
        const out_len = 4-self.n_enc % 4;

        if (self.pad_char) |pad_char| {
            for(0..out_len) |i| {
                dest[out_idx + i] = pad_char;
            }
        }
        
        self.acc_len = 0;
        self.acc = 0;
        self.n_enc = 0;

        return dest[0..out_idx + out_len];
    }
};

pub const Error = error{
    InvalidCharacter,
    InvalidPadding,
    NoSpaceLeft,
};

pub const b64Decoder = struct {
    const invalid_char: u8 = 0xff;
    acc: u12 = 0,
    acc_len: u4 = 0,
    n_dec: usize = 0,

    leftover_idx: ?usize = null,

    /// e.g. 'A' => 0.
    /// `invalid_char` for any value not in the 64 alphabet chars.
    char_to_index: [256]u8,
    pad_char: ?u8,

    pub fn init(pad_char: ?u8) b64Decoder {
        var result = b64Decoder{
            .char_to_index = [_]u8{invalid_char} ** 256,
            .pad_char = pad_char,
        };

        var char_in_alphabet = [_]bool{false} ** 256;
        for ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", 0..) |c, i| {
            assert(!char_in_alphabet[c]);
            assert(pad_char == null or c != pad_char.?);

            result.char_to_index[c] = @as(u8, @intCast(i));
            char_in_alphabet[c] = true;
        }
        return result;
    }

    /// dest.len must be what you get from ::calcSize.
    /// invalid characters result in error.InvalidCharacter.
    /// invalid padding results in error.InvalidPadding.
    pub fn decodeBatch(self: *b64Decoder, dest: []u8, source: []const u8) ![]u8 {
        //var acc: u12 = 0;
        //var acc_len: u4 = 0;
        var dest_idx: usize = 0;
        
        for (source, 0..) |c, src_idx| {
            const d = self.char_to_index[c];
            if (d == invalid_char) {
                if (self.pad_char == null or c != self.pad_char.?) return error.InvalidCharacter;
                self.leftover_idx = src_idx;
                break;
            }
            self.acc = (self.acc << 6) + d;
            self.acc_len += 6;
            if (self.acc_len >= 8) {
                self.acc_len -= 8;
                dest[dest_idx] = @as(u8, @truncate(self.acc >> self.acc_len));
                dest_idx += 1;
            }
        }
        self.n_dec += dest_idx;

        return dest[0..dest_idx];
        

    }

    pub fn decodeDanglers(self: *b64Codec, source: []u8) []const u8 {
        if (self.acc_len > 4 or (self.acc & (@as(u12, 1) << self.acc_len) - 1) != 0) {
            return error.InvalidPadding;
        }
        if (self.leftover_idx == null) return;
        const leftover = source[self.leftover_idx.?..];
        if (self.pad_char) |pad_char| {
            const padding_len = self.acc_len / 2;
            var padding_chars: usize = 0;
            for (leftover) |c| {
                if (c != pad_char) {
                    return if (c == b64Decoder.invalid_char) error.InvalidCharacter else error.InvalidPadding;
                }
                padding_chars += 1;
            }
            if (padding_chars != padding_len) return error.InvalidPadding;
        }
    }
};


pub fn main() !u8 {
    const exe_return: u8 = EXIT_SUCCESS;
    _ = exe_return;
    stdout = std.io.getStdOut().writer();
    stderr = std.io.getStdErr().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();


    var args = std.ArrayList([]const u8).init(heapalloc);
    try cli.args.appendToArrayList(&args, heapalloc);
    const exe_name = args.items[0];

    const cwd = std.fs.cwd();
    var nfilenames: usize = 0;
    for(args.items[1..]) |arg| {
        // Move anything that isn't a valid option to the beginning of args - take the bottom
        // slice for use as filenames later
        if(!try test_option_validity_and_store(arg)){
            args.items[nfilenames] = arg;
            nfilenames += 1;
        }

        // do this in the loop to allow early exit
        if(flag_dispHelp){
            try print_usage(exe_name);
            return EXIT_SUCCESS;
        }
        if(flag_dispVersion){
            try library.print_exe_version(stdout, base_exe_name);
            return EXIT_SUCCESS;
        }
    }
    const filenames = args.items[0..nfilenames];
    var fin: std.fs.File = undefined;
    if(filenames.len == 0 or std.mem.eql(u8, "-", filenames[0])){
        //use std-in
        fin = std.io.getStdIn();
    }
    else{
        fin = cwd.openFile(filenames[0], .{}) catch |err| {
            try report_fileopen_error(err, filenames[0], exe_name);
            return EXIT_FAILURE;
        };
    }
    defer fin.close();
    
    
    var buffer_small: [buffer_size]u8   = undefined;
    var buffer_big:   [2*buffer_size]u8 = undefined;
    if(flag_decode){        
        var dec = b64Decoder.init('=');
        var finished = false;
        while(!finished){
            const nread = try fin.read(&buffer_small);
            const readslice = buffer_small[0..nread];
            const plaintext = try dec.decodeBatch(&buffer_big, readslice);

            try stdout.print("{s}", .{plaintext});
            
            finished = (nread == 0);
        }
        return EXIT_SUCCESS;
    }
    
    //var enc = std.base64.Base64Encoder.init(codec.alphabet_chars, null);
    var enc: b64Codec = .{};
    var finished = false;
    while(!finished){
        const nread = try fin.read(&buffer_small);
        const readslice = buffer_small[0..nread];
        //var plaintext = enc.encode(&buffer_big, readslice);
        const ciphertext = enc.encodeBatch(&buffer_big, readslice);
        
        try stdout.print("{s}", .{ciphertext});
        
        finished = (nread == 0);
    }
    //try stdout.print("\n", .{});
    try stdout.print("{s}\n", .{enc.encodeDanglers(&buffer_big)});
    return EXIT_SUCCESS;

}