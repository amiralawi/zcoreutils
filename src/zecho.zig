const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;

var append_newline = false;
var handle_escapes = false;
var args: std.ArrayList([]const u8) = undefined;
var args_to_print: std.ArrayList([]const u8) = undefined;

fn parse_cli_args() !void {
    for (args.items[1..]) |arg| {
        if (std.mem.startsWith(u8, arg, "-")) {
            var arg_is_printable = false;
            var loop_newline = append_newline;
            var loop_escapes = handle_escapes;

            for (arg[1..]) |ch| {
                switch (ch) {
                    'n' => {
                        loop_newline = true;
                    },
                    'e' => {
                        loop_escapes = true;
                    },
                    'E' => {
                        loop_escapes = false;
                    },
                    else => {
                        arg_is_printable = true;
                    },
                }
            }

            if (arg_is_printable) {
                try args_to_print.append(arg);
            } else {
                append_newline = loop_newline;
                handle_escapes = loop_escapes;
            }
        } else {
            try args_to_print.append(arg);
        }
    }
}

const escape_state = enum {
    unescaped,
    escape_started,
    octal,
    hexadecimal,
    unicode_little,
    unicode_big,
};

pub fn print_octal_char() !void {
    var accum: u32 = 0;
    while(ebuffer.read()) |ch| {
        accum = 8*accum + util.char.getOctalValue(ch);
    }
    var accum_trunc: u8 = @truncate(accum);
    try stdout.print("{c}", .{ accum_trunc } );
}

pub fn print_hex_char() !void {
    var accum: u32 = 0;
    while(ebuffer.read()) |ch| {
        accum = 16*accum + util.char.getHexValue(ch);
    }
    var accum_trunc: u8 = @truncate(accum);
    try stdout.print("{c}", .{ accum_trunc } );
}

pub fn print_unicode_char() !void {
    // TODO
}

var e_state: escape_state = .unescaped;

var ebuffer_data: [16]u8 = undefined;
var ebuffer_fba = std.heap.FixedBufferAllocator.init(&ebuffer_data);
var ebuffer: std.RingBuffer = undefined;

var estack : [16]u8 = undefined;
var istack : usize = 0;
var suppress_flag = false;

pub fn process_char(ch: u8) !void {
    switch(e_state){
        .unescaped => {
            if(ch == '\\'){
                e_state = .escape_started;
            }
            else{
                try stdout.print("{c}", .{ch});
            }
        },
        .escape_started => {
            switch(ch){
                'a'  => { try stdout.print("{c}", .{0x07});  e_state = .unescaped; },
                'b'  => { try stdout.print("{c}", .{0x08});  e_state = .unescaped; },
                
                // TODO - not quite sure how to handle \e and \E characters - need to do more research
                //'e'  => { try stdout.print("\a", .{}); escape_stack_size = 0; },
                //'E'  => { try stdout.print("\a", .{}); escape_stack_size = 0; },
                
                'f'  => { try stdout.print("{c}", .{0xFF});  e_state = .unescaped; },
                'n'  => { try stdout.print("\n", .{});  e_state = .unescaped; },
                'r'  => { try stdout.print("\r", .{});  e_state = .unescaped; },
                't'  => { try stdout.print("\t", .{});  e_state = .unescaped; },
                'v'  => { try stdout.print("{c}", .{0x7C});  e_state = .unescaped; },
                '\\' => { try stdout.print("{c}", .{'\\'});  e_state = .unescaped; } ,
                '0'  => { e_state = .octal; },
                'x'  => { e_state = .hexadecimal; },
                'u'  => { e_state = .unicode_little; },
                'U'  => { e_state = .unicode_big; },

                'c'  => { 
                    suppress_flag = true;
                    e_state = .unescaped;
                    return;
                },
                
                else => { e_state = .unescaped; }
            }
        },
        .octal => {
            // octal \0nnn, n can be 0 to 3 octal digits
            if(!util.char.isOctal(ch)){
                try print_octal_char();
                e_state = .unescaped;
                try process_char(ch);
            }
            else{
                try ebuffer.write(ch);
                if(ebuffer.len() == 3){
                    try print_octal_char();
                    e_state = .unescaped;
                }    
            }
        },
        .hexadecimal => {
            // hexadecimal \xHH, H can be 1 or 2 hex digits
            
            if(!std.ascii.isHex(ch)){
                try print_hex_char();
                e_state = .unescaped;
                try process_char(ch);
            }
            else{
                try ebuffer.write(ch);
                if(ebuffer.len() == 2){
                    try print_hex_char();
                    e_state = .unescaped;
                }    
            }
        },
        .unicode_little => {
            // TODO - finish placeholder
            // unicode \uHHHH, H can be 1 to 4 hex digits
            e_state = .unescaped; 
        },
        .unicode_big => {
            // TODO - finish placeholder
            // unicode \UHHHHHHHH, H can be 1 to 8 hex digits
                e_state = .unescaped; 
        },
    }
}

pub fn print_dangling_escape_sequences() !void {
    switch(e_state){
        .octal =>{ try print_octal_char(); },
        .hexadecimal =>{ try print_hex_char(); },
        .unicode_little, .unicode_big =>{
            try print_unicode_char();
        },
        else => {}
    }
}

pub fn main() !void {
    stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var ebuff_alloc = ebuffer_fba.allocator();
    ebuffer = try std.RingBuffer.init(ebuff_alloc, 16);
    defer ebuffer.deinit(ebuff_alloc);
    
    const allocator = arena.allocator();

    // get CLI args
    args = std.ArrayList([]const u8).init(allocator);
    args_to_print = std.ArrayList([]const u8).init(allocator);
    try cli.args.appendToArrayList(&args, allocator);

    try parse_cli_args();
    var n_printable = args_to_print.items.len;
    
    // dumb path
    if(!handle_escapes){
        for (args_to_print.items, 1..) |arg, index| {
            var suffix = if (index == n_printable) "" else " ";
            try stdout.print("{s}{s}", .{ arg, suffix });
        }
        if (append_newline == false) {
            try stdout.print("\n", .{});
        }
        return;
    }

    // escape sequence path
    for (args_to_print.items, 1..) |arg, index| {
        var suffix = if (index == n_printable) "" else " ";
        
        for(arg) |ch|{
            try process_char(ch);           
        }

        try print_dangling_escape_sequences();

        try stdout.print("{s}", .{suffix});
    }
    
    if (append_newline == false and suppress_flag == false) {
        try stdout.print("\n", .{});
    }
}
