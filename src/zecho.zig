const util = @import("./util.zig");
const std = @import("std");

fn append_cli_args(container: *std.ArrayList([]const u8), allocator: std.mem.Allocator) !void {
    var argiter = try std.process.argsWithAllocator(allocator);
    while (argiter.next()) |arg| {
        try container.append(arg);
    }
}

var options_n = false;
var options_E = false;
var options_e = false;
var args: std.ArrayList([]const u8) = undefined;
var args_to_print: std.ArrayList([]const u8) = undefined;

fn parse_cli_args() !void {
    for (args.items[1..]) |arg| {
        //if (arg.len > 1 and util.string.startsWith(&arg, "-") and util.string.countChar(&arg, '-') == 1) {
        if (util.u8str.startsWith(arg, "-")) {
            var arg_is_printable = false;
            var loop_has_n = false;
            var loop_has_E = false;
            var loop_has_e = false;

            for (arg[1..]) |ch| {
                switch (ch) {
                    'n' => {
                        loop_has_n = true;
                    },
                    'e' => {
                        loop_has_e = true;
                        loop_has_E = false;
                    },
                    'E' => {
                        loop_has_E = true;
                        loop_has_e = false;
                    },
                    else => {
                        arg_is_printable = true;
                    },
                }
            }

            if (arg_is_printable) {
                try args_to_print.append(arg);
            } else {
                if (loop_has_n) {
                    options_n = true;
                }
                if (loop_has_E) {
                    options_E = true;
                    options_e = false;
                }
                if (loop_has_e) {
                    options_E = false;
                    options_e = true;
                }
            }
        } else {
            try args_to_print.append(arg);
        }
    }
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // get CLI args
    args = std.ArrayList([]const u8).init(allocator);
    args_to_print = std.ArrayList([]const u8).init(allocator);
    try append_cli_args(&args, allocator);

    try parse_cli_args();

    // now do the echoing
    // TODO: add support for escape characters (options -e and -E)
    var n_printable = args_to_print.items.len;
    var suppress_flag = false;
    for (args_to_print.items, 1..) |arg, index| {
        var suffix = if (index == n_printable) "" else " ";
        
        var escape_stack : [16]u8 = undefined;
        var escape_stack_size: i32 = 0;

        if(options_e){
            for(arg) |ch|{
                if(escape_stack_size == 0){
                    if(ch == '\\'){
                        escape_stack_size = 1;
                        escape_stack[0] = '\\';
                    }
                    else{
                        try stdout.print("{c}", .{ch});
                    }
                }
                else if(escape_stack_size == 1){
                    switch(ch){
                        'a'  => { try stdout.print("{c}", .{0x07}); escape_stack_size = 0; },
                        'b'  => { try stdout.print("{c}", .{0x08}); escape_stack_size = 0; },
                        
                        // TODO - not quite sure how to handle \e and \E characters - need to do more research
                        //'e'  => { try stdout.print("\a", .{}); escape_stack_size = 0; },
                        //'E'  => { try stdout.print("\a", .{}); escape_stack_size = 0; },
                        'f'  => { try stdout.print("{c}", .{0xFF}); escape_stack_size = 0; },
                        'n'  => { try stdout.print("\n", .{}); escape_stack_size = 0; },
                        'r'  => { try stdout.print("\r", .{}); escape_stack_size = 0; },
                        't'  => { try stdout.print("\t", .{}); escape_stack_size = 0; },
                        'v'  => { try stdout.print("{c}", .{0x7C}); escape_stack_size = 0; },
                        '\\' => { try stdout.print("{c}", .{'\\'}); escape_stack_size = 0; } ,

                        'c'  => { 
                            suppress_flag = true;
                            escape_stack_size = 0;
                            return;
                        },

                        // TODO - these all need implementation
                        // octal \0nnn, n can be 0 to 3 octal digits
                        '0' => {},

                        // hexadecimal \xHH, H can be 1 or 2 hex digits
                        'x' => {},

                        // unicode \uHHHH, H can be 1 to 4 hex digits
                        'u' => {},

                        // unicode \uHHHHHHHH, H can be 1 to 8 hex digits
                        'U' => {},
                        
                        else => { escape_stack_size = 0; }

                        
                    }


                }
                else if(escape_stack_size > 1){
                    // TODO - handle this better
                    escape_stack_size = 0;
                }
                
                
            }

        }
        else{
            try stdout.print("{s}", .{ arg });
        }

        try stdout.print("{s}", .{suffix});
    }
    

    if (options_n == false and suppress_flag == false) {
        try stdout.print("\n", .{});
    }
}
