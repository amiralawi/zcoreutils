const generic = @import("./zcorecommon/generic.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");
const testing = std.testing;

var stdout: std.fs.File.Writer = undefined;

pub fn makePath(self: std.fs.Dir, sub_path: []const u8) !void {
    var it = try std.fs.path.componentIterator(sub_path);
    var component = it.last() orelse return;
    while (true) {
        self.makeDir(component.path) catch |err| switch (err) {
            error.PathAlreadyExists => {
                // stat the file and return an error if it's not a directory
                // this is important because otherwise a dangling symlink
                // could cause an infinite loop
                var fstat = self.statFile(sub_path) catch { return err; };
                if(fstat.kind != .directory){ return error.NotDir; }
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

    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    var buf_alloc = fba.allocator();

    var tmp = tmpDir(.{});
    defer tmp.cleanup();
    
    try tmp.dir.makeDir("foo");
    var foo = try tmp.dir.openDir("foo", .{});
    defer foo.close();
    var bar = try foo.createFile("bar", .{});
    defer bar.close();

    var sub_path = try std.fs.path.join(buf_alloc, &[_][]const u8{"foo", "bar", "baz"});


    try stdout.print("tmp -> '{s}'\n", .{sub_path});
    //try tmp.dir.makePath(sub_path);

    var path = try tmp.dir.realpath(".", &buf);
    try stdout.print("tmp -> '{s}'\n", .{path});

    //var filename = "a";

    //var cwd = std.fs.cwd();
    //try cwd.makePath(filename);
    //try stdout.print("done\n", .{});
}

pub const TmpDir = struct {
    dir: std.fs.Dir,
    parent_dir: std.fs.Dir,
    sub_path: [sub_path_len]u8,

    const random_bytes_count = 12;
    const sub_path_len = std.fs.base64_encoder.calcSize(random_bytes_count);

    pub fn cleanup(self: *TmpDir) void {
        self.dir.close();
        self.parent_dir.deleteTree(&self.sub_path) catch {};
        self.parent_dir.close();
        self.* = undefined;
    }
};

pub fn tmpDir(opts: std.fs.Dir.OpenDirOptions) TmpDir {
    var random_bytes: [TmpDir.random_bytes_count]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);
    var sub_path: [TmpDir.sub_path_len]u8 = undefined;
    _ = std.fs.base64_encoder.encode(&sub_path, &random_bytes);

    var cwd = std.fs.cwd();
    var cache_dir = cwd.makeOpenPath("zig-cache", .{}) catch
        @panic("unable to make tmp dir for testing: unable to make and open zig-cache dir");
    defer cache_dir.close();
    var parent_dir = cache_dir.makeOpenPath("tmp", .{}) catch
        @panic("unable to make tmp dir for testing: unable to make and open zig-cache/tmp dir");
    var dir = parent_dir.makeOpenPath(&sub_path, opts) catch
        @panic("unable to make tmp dir for testing: unable to make and open the tmp dir");

    return .{
        .dir = dir,
        .parent_dir = parent_dir,
        .sub_path = sub_path,
    };
}



test "makePath but sub_path contains pre-existing file" {
    // makePath tmp/foo/bar/baz, but bar is a file
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    var buf_alloc = fba.allocator();

    var tmp = tmpDir(.{});
    defer tmp.cleanup();
    
    try tmp.dir.makeDir("foo");
    var foo = try tmp.dir.openDir("foo", .{});
    defer foo.close();
    var bar = try foo.createFile("bar", .{});
    defer bar.close();

    var sub_path = try std.fs.path.join(buf_alloc, &[_][]const u8{"foo", "bar", "baz"});
    try testing.expectError(error.NotDir, tmp.dir.makePath(sub_path));
}