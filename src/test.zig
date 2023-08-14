const generic = @import("./zcorecommon/generic.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");

var stdout: std.fs.File.Writer = undefined;

pub fn makePath(self: std.fs.Dir, sub_path: []const u8) !void {
    var it = try std.fs.path.componentIterator(sub_path);
    var component = it.last() orelse return;
    while (true) {
        self.makeDir(component.path) catch |err| switch (err) {
            error.PathAlreadyExists => {
                // TODO stat the file and return an error if it's not a directory
                // this is important because otherwise a dangling symlink
                // could cause an infinite loop
                var s = try self.statFile(sub_path);
                if(s.kind != .directory){ return error.PathIsNotDir; }
            },
            error.FileNotFound => |e| {
                component = it.previous() orelse return e;
                continue;
            },
            else => |e| return e,
        };
        component = it.next() orelse return;
    }
}

pub fn main() !void {
    stdout = std.io.getStdOut().writer();

    var filename = "a";

    var cwd = std.fs.cwd();
    try makePath(cwd, filename);
    try stdout.print("done\n", .{});
}