const library = @import("./zcorecommon/library.zig");
const cli = @import("./zcorecommon/cli.zig");
const util = @import("./zcorecommon/util.zig");
const std = @import("std");
const stdout = std.io.getStdOut().writer();

const base_exe_name = "zsleep";


pub fn print_usage(exe_name: []const u8) !void {
    try stdout.print(
        \\Usage: {s} NUMBER[SUFFIX]...\n
        \\  or:  sleep OPTION
        \\Pause for NUMBER seconds.  Optional SUFFIX may be one of:
        \\  's' for seconds (the default)
        \\  'm' for minutes
        \\  'h' for hours
        \\  'd' for days
        \\NUMBER may be any positive integer or floating-point number. Given
        \\two or more arguments, pause for the amount of time specified by
        \\the sum of their values.
        \\
    , .{ exe_name }
    );
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
        if(util.u8str.cmp(args.items[1], "--help")){
            try print_usage(exe_name);
            return;
        }
        else if(util.u8str.cmp(args.items[1], "--version")){
            try library.print_exe_version(base_exe_name);
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