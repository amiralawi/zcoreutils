const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;

const base_exe_name = "zhead";
const EXIT_FAILURE: u8 = 1;
const EXIT_SUCCESS: u8 = 0;
const read_buffer_size = 2048;

pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(
        \\Usage: {0s} [OPTION]... [FILE]...
        \\Print the first 10 lines of each FILE to standard output.
        \\With more than one FILE, precede each with a header giving the file name.
        \\
        \\With no FILE, or when FILE is -, read standard input.
        \\
        \\Mandatory arguments to long options are mandatory for short options too.
        \\  -c, --bytes=[-]NUM[suf]  print the first NUM bytes of each file;
        \\                             with the leading '-', print all but the last
        \\                             NUM bytes of each file
        \\  -n, --lines=[-]NUM[suf]  print the first NUM lines instead of the first 10;
        \\                             with the leading '-', print all but the last
        \\                             NUM lines of each file
        \\  -q, --quiet, --silent    never print headers giving file names
        \\  -v, --verbose            always print headers giving file names
        \\  -z, --zero-terminated    line delimiter is NUL, not newline
        \\      --help     display this help and exit
        \\      --version  output version information and exit
        \\
        \\NUM may have a multiplier suffix:
        \\b 512, kB 1000, K 1024, MB 1000*1000, M 1024*1024,
        \\GB 1000*1000*1000, G 1024*1024*1024, and so on for T, P, E.
        \\    -> Z, Y not implemented
        \\
        ,.{exe_name}
    );
}

const lastParsedOption = enum{ bytecount, linecount, other };
const FileHeaderType = enum { always, sometimes, never };
const CountType = enum { bytes, lines };

// default behaviors
var count_max:usize = 10;
var behavior_count = CountType.lines;
var header_behavior = FileHeaderType.sometimes;
var delimiter_eol: u8 = '\n';

var flag_dispHelp = false;
var flag_dispVersion = false;


pub fn head_file_lines(file: std.fs.File, nlines: usize) !void{
    var buffer: [read_buffer_size]u8 = undefined;
    var finished = false;

    var lines_printed:usize = 0;
        while(!finished){
            var nread = try file.read(&buffer);
            var readslice = buffer[0..nread];
            
            var print_iend: usize = readslice.len;
            for(readslice, 1..) |ch, i|{
                if(ch == delimiter_eol){
                    lines_printed += 1;
                    if(lines_printed >= nlines){
                        print_iend = i;
                        break;
                    }
                }
            }
            try stdout.print("{s}", .{ buffer[0..print_iend] });
            
            finished = (lines_printed >= nlines) or (nread == 0);
        }
}

pub fn head_file_bytes(file: std.fs.File, nbytes: usize) !void{
    var buffer: [read_buffer_size]u8 = undefined;
    var finished = false;

    var bytes_written:usize = 0;
        while(!finished){
            var nread = try file.read(&buffer);
            var readslice = buffer[0..nread];
            var bytes_remaining = nbytes - bytes_written;

            if(nread > bytes_remaining){
                try stdout.print("{s}", .{readslice[0..bytes_remaining]});
                bytes_written += bytes_remaining;
            }
            else{
                try stdout.print("{s}", .{ readslice });
                bytes_written += nread;
            }
            
            finished = (bytes_written >= nbytes) or (nread == 0);
        }
}

pub fn head_file(file: std.fs.File) !void {
    if(behavior_count == .lines){
        try head_file_lines(file, count_max);
    }
    else if(behavior_count == .bytes){
        try head_file_bytes(file, count_max);
    }
}

pub fn extractIntWithSuffix(str: []const u8) !i64 {
    //search for [-]NUM[suffix]
    //NUM may have a multiplier suffix:
    //b 512, kB 1000, K 1024, MB 1000*1000, M 1024*1024,
    //GB 1000*1000*1000, G 1024*1024*1024, and so on for T, P, E, Z, Y.
    
    if(str.len <= 1){
        return std.fmt.parseInt(i64, str, 10);
    }

    var mult: i64 = 1;
    var suffix_len: usize = 1;
    
    switch(str[str.len-1]){
        'b' => { mult = 512; },
        'K' => { mult = 1024; },
        'M' => { mult = 1024*1024; },
        'G' => { mult = 1024*1024*1024; },
        'T' => { mult = 1024*1024*1024*1024; },
        'P' => { mult = 1024*1024*1024*1024*1024; },
        'E' => { mult = 1024*1024*1024*1024*1024*1024; },

        // These numbers are impractically large and require something bigger than u64
        // 'Z' => { mult = 1024*1024*1024*1024*1024*1024*1024; },
        // 'Y' => { mult = 1024*1024*1024*1024*1024*1024*1024*1024; },
        'B' => {
            suffix_len = 2;
            if(str.len < 2)
                switch(str[str.len - 2]){
                    'k' => { mult = 1000*1000; },
                    'M' => { mult = 1000*1000; },
                    'G' => { mult = 1000*1000*1000; },
                    'T' => { mult = 1000*1000*1000*1000; },
                    'P' => { mult = 1000*1000*1000*1000*1000; },
                    'E' => { mult = 1000*1000*1000*1000*1000*1000; },

                    // These numbers are impractically large and require something bigger than u64
                    // 'Z' => { mult = 1000*1000*1000*1000*1000*1000*1000; },
                    // 'Y' => { mult = 1000*1000*1000*1000*1000*1000*1000*1000; },
                    else=> { 
                        return error.UnrecognizedMultiplierSuffix;
                    }
                };
        },
        else =>{ suffix_len = 0; }
    }
    
    // TODO - check extracted size vs multiplier for overflow
    var base = std.fmt.parseInt(i64, str[0..str.len-suffix_len], 10) catch |err|{ return err; };
    return base * mult;
}

var last_option = lastParsedOption.other;
var ignore_options = false;
pub fn test_option_validity_and_store(str: []const u8) !bool {
    if(ignore_options){
        return false;
    }
    switch(last_option){
        .bytecount =>{
            var count = try extractIntWithSuffix(str);
            if(count < 0){
                // TODO - handle negative
            }
            else{
                count_max = @intCast(count);
            }
            last_option = .other;
            return true;
        },
        .linecount =>{
            var count = try std.fmt.parseInt(i32, str, 10);
            if(count < 0){
                // TODO - handle negative
            }else{
                count_max = @intCast(count);
            }
            
            last_option = .other;
            return true;
        },
        .other => {}
    }
    if(!util.u8str.startsWith(str, "-")){
        // exit early
        return false;
    }
    if(util.u8str.cmp(str, "--")){
        ignore_options = true;
        return true;
    }
    if(util.u8str.cmp(str, "--help")){
        flag_dispHelp = true;
        return true;
    }
    if(util.u8str.cmp(str, "--version")){
        flag_dispVersion = true;
        return true;
    }
    if(util.u8str.cmp(str, "--verbose")){
        header_behavior = .always;
        return true;
    }
    if(util.u8str.cmp(str, "--quiet")){
        header_behavior = .never;
        return true;
    }
    if(util.u8str.cmp(str, "--silent")){
        header_behavior = .never;
        return true;
    }
    if(util.u8str.cmp(str, "--zero-terminated")){
        delimiter_eol = '\x00';
        return true;
    }
    // if(util.u8str.startsWith(str, "--lines")){
    //     // TODO
    //     return true;
    // }
    // if(util.u8str.startsWith(str, "--bytes")){
    //     // TODO
    //     return true;
    // }
    if(util.u8str.startsWith(str, "-") and str.len > 1){
        var all_chars_valid_flags = true;
        for(str[1..]) |ch| {
            switch(ch){
                'c', 'n', 'q', 'v', 'z' => {},
                else => { all_chars_valid_flags = false; },
            }
        }

        if(!all_chars_valid_flags){
            return false;
        }

        for(str[1..]) |ch| {
            switch(ch){
                'c' => { last_option = .bytecount; behavior_count = .bytes; },
                'n' => { last_option = .linecount; behavior_count = .lines; },
                'q' => { header_behavior = .never; },
                'v' => { header_behavior = .always; },
                'z' => { delimiter_eol = '\x00'; },
                else => unreachable,
            }
        }
        return true;
    }
    return false;
}

pub fn report_head_error(err: anyerror, filename: []const u8, exe_name: []const u8) !void {
    switch(err){          
        error.FileNotFound =>{
            try stderr.print("{s}: cannot open '{s}' for reading: No such file or directory\n", .{exe_name, filename});
        },
        error.IsDir => {
            try stderr.print("{s}: error reading '{s}': Is a directory\n", .{exe_name, filename});
        },
        error.AccessDenied => {
            try stderr.print("{s}: cannot open '{s}' for reading: Permission denied\n", .{exe_name, filename});
        },
        else => {
            try stderr.print("{s}: cannot open '{s}': unrecognized error '{any}'\n", .{exe_name, filename, err});
        },
    }
}

pub fn main() !u8 {
    stdout = std.io.getStdOut().writer();
    stderr = std.io.getStdErr().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();

    var args = std.ArrayList([]const u8).init(heapalloc);
    try cli.args.appendToArrayList(&args, heapalloc);
    var exe_name = args.items[0];
    
    // process options & update globals
    var nfilenames: usize = 0;
    for(args.items[1..]) |arg| {
        if(test_option_validity_and_store(arg)) |store|{
            // Move anything that isn't a valid option to the beginning of args - take the bottom
            // slice for use as filenames later
            if(!store){
                args.items[nfilenames] = arg;
                nfilenames += 1;
            }
        }
        else |err| {
            switch(err){
                error.InvalidCharacter => {
                    var invalid_type = if(behavior_count == .lines) "lines" else "bytes";
                    try stdout.print("{s}: invalid number of {s}: '{s}'\n", .{exe_name, invalid_type, arg});
                },        
                else => { try stdout.print("{s}: error processing argument '{s}': {any}\n", .{exe_name, arg, err}); }
            }
            return EXIT_FAILURE;
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

    if(filenames.len == 0){
        // no file argument passed, read standard input instead
        var stdin = std.io.getStdIn();
        try head_file(stdin);
        return EXIT_SUCCESS;
    }

    var cwd = std.fs.cwd();
    
    for(filenames, 0..) |filename, i| {
        // 1 - open file
        var file = cwd.openFile(filename, .{}) catch |err|{
            try report_head_error(err, filename, exe_name);
            continue;
        };
        defer file.close();
        
        // 2 - print filename header if we have more than one file
        if(header_behavior == .always or (header_behavior == .sometimes and filenames.len > 1)){
            var prefix = if(i > 0) "\n" else "";
            try stdout.print("{s}==> {s} <==\n", .{prefix, filename});
        }

        // 3 - print head lines for file
        try head_file(file);
    }
    return EXIT_SUCCESS;
}