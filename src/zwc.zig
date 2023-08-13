const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;

const base_exe_name = "zwc";
const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;
const buffer_size = 2048;

pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(
        \\Usage: {0s} [OPTION]... [FILE]...
        \\  or:  {0s} [OPTION]... --files0-from=F
        \\Print newline, word, and byte counts for each FILE, and a total line if
        \\more than one FILE is specified.  A word is a non-zero-length sequence of
        \\characters delimited by white space.
        \\
        \\With no FILE, or when FILE is -, read standard input.
        \\
        \\The options below may be used to select which counts are printed, always in
        \\the following order: newline, word, character, byte, maximum line length.
        \\  -c, --bytes            print the byte counts
        \\  -m, --chars            print the character counts
        \\  -l, --lines            print the newline counts
        \\      --files0-from=F    read input from the files specified by
        \\                           NUL-terminated names in file F;
        \\                           If F is - then read names from standard input
        \\  -L, --max-line-length  print the maximum display width
        \\  -w, --words            print the word counts
        \\      --help     display this help and exit
        \\      --version  output version information and exit
        \\
        , .{ exe_name}
    );
}

const ExpectedOptionValType = enum { none };
var expected_option: ExpectedOptionValType = .none;

var flag_dispVersion = false;
var flag_dispHelp = false;

var flag_defaults = true;
var flag_bytes = false;
var flag_chars = false;
var flag_lines = false;
var flag_words = false;
var flag_maxlinelen = false;

var ignore_options = false;

pub fn set_defaults() void {
    flag_bytes = false;
    flag_chars = true;
    flag_lines = true;
    flag_words = true;
    flag_maxlinelen = false;
}

pub fn get_print_len(a: usize) usize {
    var n:usize = 1;
    var b = a / 10;
    while(b > 0){
        b = b / 10;
        n += 1;
    }
    return n;
}

pub fn print_summary(s: wc_summary) !void {
    //try stdout.print(" {d} {d} {d} {s}\n", .{lines, words, bytes, "filename"});
    // order -> lines words bytes filename
    
    //get pad count
    var maxlen: usize = 0;
    if(flag_lines){
        maxlen = @max(maxlen, get_print_len(s.lines));
    }
    if(flag_words){
        maxlen = @max(maxlen, get_print_len(s.words));
    }
    if(flag_chars){
        maxlen = @max(maxlen, get_print_len(s.chars));
    }
    if(flag_bytes){
        maxlen = @max(maxlen, get_print_len(s.bytes));
    }
    if(flag_maxlinelen){
        maxlen = @max(maxlen, get_print_len(s.maxlinelen));
    }



    var prefix: []const u8 = "";
    if(flag_lines){
        var len = get_print_len(s.lines);
        for(0..maxlen-len)|_|{try stdout.print(" ", .{});}
        try stdout.print("{s}{d: >}", .{prefix, s.lines});
        prefix = " ";
    }
    if(flag_words){
        var len = get_print_len(s.words);
        for(0..maxlen-len)|_|{try stdout.print(" ", .{});}
        try stdout.print("{s}{d}", .{prefix, s.words});
        prefix = " ";
    }
    if(flag_chars){
        var len = get_print_len(s.chars);
        for(0..maxlen-len)|_|{try stdout.print(" ", .{});}
        try stdout.print("{s}{d}", .{prefix, s.chars});
        prefix = " ";
    }
    if(flag_bytes){
        var len = get_print_len(s.bytes);
        for(0..maxlen-len)|_|{try stdout.print(" ", .{});}
        try stdout.print("{s}{d}", .{prefix, s.bytes});
        prefix = " ";
    }
    if(flag_maxlinelen){
        var len = get_print_len(s.maxlinelen);
        for(0..maxlen-len)|_|{try stdout.print(" ", .{});}
        try stdout.print("{s}{d}", .{prefix, s.maxlinelen});
        prefix = " ";
    }
    if(!util.u8str.cmp(s.name, "")){
        try stdout.print(" {s}", .{s.name});
    }

    try stdout.print("\n", .{});
}


pub fn test_option_validity_and_store(str: []const u8) bool {
    if(ignore_options){
        return false;
    }
    switch(expected_option){
        .none => {}
    }
    if(util.u8str.startsWith(str, "--")){
        return test_option_validity_and_store(str);
    }
    else if(util.u8str.startsWith(str, "-")){
        if(str.len == 1){
            // "-" refers to standard input
            return false;
        }
        var all_chars_valid_flags = true;
        for(str[1..]) |ch| {
            switch(ch){
                'c', 'm', 'l', 'L', 'w' => {},
                else => { all_chars_valid_flags = false; },
            }
        }

        if(!all_chars_valid_flags){
            return false;
        }

        for(str[1..]) |ch| {
            switch(ch){
                'c' => { flag_defaults = false; flag_bytes = true; },
                'm' => { flag_defaults = false; flag_chars = true; },
                'l' => { flag_defaults = false; flag_lines = true; },
                'L' => { flag_defaults = false; flag_maxlinelen = true; },
                'w' => { flag_defaults = false; flag_words = true; },
                else => unreachable,
            }
        }
        return true;
    }
    return false;
}

pub fn test_long_option_validity_and_store(str: []const u8) bool {
    // this function only gets called when str starts with "--"
    if(util.u8str.cmp(str, "--")){
        ignore_options = true;
        return true;
    }

    var option = str[2..];
    if(util.u8str.cmp(option, "version")){
        flag_dispVersion = true;
        return true;
    }
    if(util.u8str.cmp(option, "help")){
        flag_dispHelp = true;
        return true;
    }
    if(util.u8str.cmp(option, "bytes")){
        flag_defaults = false;
        flag_bytes = true;
        return true;
    }
    if(util.u8str.cmp(option, "chars")){
        flag_defaults = false;
        flag_chars = true;
        return true;
    }
    if(util.u8str.cmp(option, "lines")){
        flag_defaults = false;
        flag_lines = true;
        return true;
    }
    if(util.u8str.cmp(option, "max-line-length")){
        flag_defaults = false;
        flag_maxlinelen = true;
        return true;
    }
    if(util.u8str.cmp(option, "words")){
        flag_defaults = false;
        flag_words = true;
        return true;
    }
    if(util.u8str.startsWith(option, "files0-from=")){
        // TODO
        return true;
    }

}

const wc_summary = struct {
    name: []const u8 = "",
    bytes: usize,
    chars: usize,
    lines: usize,
    maxlinelen: usize,
    words: usize,
};

pub fn wc_file(file: std.fs.File) !wc_summary {
    var buffer: [buffer_size]u8 = undefined;

    var finished = false;

    var s = wc_summary{
        .bytes = 0,
        .chars = 0,
        .lines = 0,
        .maxlinelen = 0,
        .words = 0,
    };

    var last_char_was_whitespace = true;
    var linestart: usize = 0;
    var wordstart: usize = 0;

    // TODO - investigate whether chars refers to unicode characters vs printable ascii
    while(!finished){
        var nread = try file.read(&buffer);
        var readslice = buffer[0..nread];

        for(readslice, s.bytes..) |ch, i| {
            s.bytes += 1;
            switch(ch){
                '\n', ' ', '\t', '\r' => { 
                    if(ch == '\n'){
                        s.lines += 1;
                        if(!last_char_was_whitespace){
                            s.maxlinelen = @max(s.maxlinelen, i-linestart);
                        }
                    }
                    if(!last_char_was_whitespace){
                        s.words += 1;
                    }
                    
                    s.chars += 1;
                    last_char_was_whitespace = true;
                },
                'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
                'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 'B',
                'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
                'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '1', '2', '3', '4',
                '5', '6', '7', '8', '9', '0', '-', '=', '~', '!', '@', '#', '$', '%',
                '^', '&', '*', '(', ')', '_', '+', '[', ']', '{', '}', '|', ';', ':',
                ',', '.', '/', '<', '>', '?', '"', '\'', '\\', =>{
                    s.chars += 1;
                    if(last_char_was_whitespace){
                        linestart = i;
                        wordstart = i;
                    }
                    last_char_was_whitespace = false;
                },
                else => {}
            }
        }
        finished = (nread == 0);
    }

    return s;
}


pub fn report_exe_error(err: anyerror, filename: []const u8, exe_name: []const u8) !void {
    switch(err){          
        error.FileNotFound =>{
            try stderr.print("{0s}: '{1s}': No such file or directory\n", .{exe_name, filename});
        },
        error.IsDir => {
            try stderr.print("{0s}: '{1s}': Is a directory\n", .{exe_name, filename});
        },
        error.AccessDenied => {
            try stderr.print("{0s}: '{1s}': Permission denied\n", .{exe_name, filename});
        },
        else => {
            try stderr.print("{0s}: '{1s}': unrecognized error '{2any}'\n", .{exe_name, filename, err});
        },
    }
}

pub fn main() !u8 {
    stdout = std.io.getStdOut().writer();
    stderr = std.io.getStdErr().writer();
    var stdin = std.io.getStdIn();
    

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();


    var args = std.ArrayList([]const u8).init(heapalloc);
    try cli.args.appendToArrayList(&args, heapalloc);
    var exe_name = args.items[0];

    const cwd = std.fs.cwd();
    var nfilenames: usize = 0;
    for(args.items[1..]) |arg| {
        // Move anything that isn't a valid option to the beginning of args - take the bottom
        // slice for use as filenames later
        if(!test_option_validity_and_store(arg)){
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
    var filenames = args.items[0..nfilenames];

    if(flag_defaults){
        set_defaults();
    }

    if(filenames.len == 0){
        // use standard input
        var summary = wc_file(stdin);
        if(summary) |summary_unwrapped|{
            var s = summary_unwrapped;
            s.name = "";
            try print_summary(s);
            return EXIT_SUCCESS;
        }
        else |err| {
            try report_exe_error(err, "-", exe_name);
        }
    }

    for(filenames) |filename| {

        var file: std.fs.File = undefined;
        if(util.u8str.cmp(filename, "-")){
            file = stdin;
        }
        file = cwd.openFile(filename, .{}) catch |err| {
            try report_exe_error(err, filename, exe_name);
            continue;
        };
        defer file.close();

        var summary = wc_file(file) catch |err| {
            try report_exe_error(err, filename, exe_name);
            continue;
        };

        summary.name = filename;
        try print_summary(summary);
    }

    return EXIT_SUCCESS;
}