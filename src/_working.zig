const library = @import("./zcorecommon/library.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

const assert = std.debug.assert;

var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;

//const allocator = std.heap.page_allocator;

//pub fn foo(comptime arr: [_]i32) void {}

const argaction = enum {
    store,
    store_true,
    callback,
    count,
    help,
    version,
};

const argdesc = struct {
    name: ?[]const u8,
    longname: ?[]const u8,
    action: i32,
};

fn max(comptime T: type, a: T, b: T) void {
    _ = a; // autofix
    _ = b; // autofix
}

fn bar(comptime n: comptime_int, a: i32[n]) void {
    _ = a; // autofix
}

fn baz(comptime n: comptime_int, a: i32[n]) f32[n] {
    _ = a;
    return .{0.0} * n;
}

fn baz2(comptime n: comptime_int, a: i32[n]) f32[n] {
    _ = a;
    return .{0.0} * n;
}

pub fn field(comptime aact: argaction, comptime T: type) type {
    _ = aact; // autofix
    return struct {
        val: ?T,
    };
}

const field2 = struct {
    x: i32,
};

const field3 = struct {
    val: i32,
    required: bool,
};

const def = struct {};

const et = enum { bool, i32, u32, u8str };

const tu = union(et) {
    bool: bool,
    u32: u32,
    i32: i32,
    u8str: []u8,
};

const bartype = struct {
    x: field(.store, u32),
    y: field(.store_true, u32),
};

pub fn main() !void {
    stdout = std.io.getStdOut().writer();
    stderr = std.io.getStdErr().writer();

    try stdout.print("==== BEGIN ====\r\n", .{});
    try stdout.print("footype(.store, i32) == footype(.store_true, i32) -> {0}\r\n", .{field(.store, i32) == field(.store_true, i32)});
    try stdout.print("field(.store, i32) == field(.store, i32) -> {0}\r\n", .{field(.store, i32) == field(.store, i32)});
    try stdout.print("\"32\"={}\r\n", .{@as(i32, 34.0)});
    try stdout.print("==== END ====\r\n", .{});
}
