const generic = @import("./zcorecommon/generic.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;

pub fn working_function() !i32 {
    return -66;
}

pub fn failing_function() !void {
    return error.baderror;
}

pub fn fail_on_positive(a: i32) !bool {
    if(a > 0){
        return error.baderror;
    }
    return true;
}

pub fn main() !void {
    stdout = std.io.getStdOut().writer();

    if(fail_on_positive(1)) |e|{
        try stdout.print("if fop -> {any}\n", .{e});
    }
    else |f| {
        try stdout.print("else fop -> {any}", .{f});
    }

}