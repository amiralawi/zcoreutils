const library = @import("./zcorecommon/library.zig");
const cli = @import("./zcorecommon/cli.zig");
const util = @import("./zcorecommon/util.zig");
const std = @import("std");
const stdout = std.io.getStdOut().writer();



pub fn print_usage() !void{
    try stdout.print("Usage: sleep NUMBER[SUFFIX]...\n", .{});
    try stdout.print("  or:  sleep OPTION\n", .{});
    try stdout.print("Pause for NUMBER seconds.  Optional SUFFIX may be one of:\n", .{});
    try stdout.print("  's' for seconds (the default)\n", .{});
    try stdout.print("  'm' for minutes\n", .{});
    try stdout.print("  'h' for hours\n", .{});
    try stdout.print("  'd' for days\n", .{});
    try stdout.print("NUMBER may be any positive integer or floating-point number. Given\n", .{});
    try stdout.print("two or more arguments, pause for the amount of time specified by\n", .{});
    try stdout.print("the sum of their values.\n", .{});
}

pub fn print_version() !void{
    try stdout.print("zsleep ({s}) {s}\n", .{library.name, library.version});
    try stdout.print("Copyright (C) {s} Amir Alawi.\n", .{library.copyright_year});
    try stdout.print("License: {s}.\n\n", .{library.license_short});
    try stdout.print("Written by Amir Alawi.\n", .{});

}


pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const heapalloc = arena.allocator();


    var args = std.ArrayList([]const u8).init(heapalloc);
    try cli.args.appendToArrayList(&args, heapalloc);
    
    var exe_name = args.items[0];
    if(args.items.len == 1){
        // no arguments supplied
        try stdout.print("{s}: missing operand\n", .{exe_name});
        try stdout.print("Try '{s} --help' for more information.\n", .{exe_name});
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

    
    var dt_accum: f64 = 0;
    for(args.items[1..]) |dt| {
        if(dt.len == 0){
            // not sure if this condition is possible, guard against just in case
            continue;
        }

        
        var dt_clean = dt;
        var mult: f64 = 1.0;
        switch(dt[dt.len - 1]){
            'm' => { dt_clean = dt[0..dt.len-1]; mult = 60.0; },
            'h' => { dt_clean = dt[0..dt.len-1]; mult = 60.0 * 60.0; },
            'd' => { dt_clean = dt[0..dt.len-1]; mult = 60.0 * 60.0 * 24.0; },
            's' => { dt_clean = dt[0..dt.len-1]; mult = 1.0; },
            else => {}
        }

        var dt_val = std.fmt.parseFloat(f64, dt_clean) catch {
            try stdout.print("{s}: invalid time interval '{s}'\n", .{exe_name, dt});
            return;
            
        };
        if(dt_val < 0.0){
            try stdout.print("{s}: invalid time interval '{s}' -> cannot be negative\n", .{exe_name, dt});
            return;
        }
        
        dt_accum += mult * dt_val;
    }

    var ns_sleep: u64 = @intFromFloat(dt_accum * 1000000000.0);
    std.time.sleep(ns_sleep);
}