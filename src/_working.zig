const String = @import("./zig-string.zig").String;
const std = @import("std");
const print = std.debug.print;
const conprint = std.debug.print;
//const allocator = std.heap.page_allocator;

const file_permission = struct {
    var r: bool = 0;
    var w: bool = 0;
    var x: bool = 0;
};

const permission = struct {
    r: bool = false,
    w: bool = false,
    x: bool = false,
};

const fs_item = struct {
    name: String,
    date_modified: String = undefined,
    date_created: String = undefined,
    owner: String = undefined,
    group: String = undefined,
    size: usize = 0,

    fs_type: enum { file, symlink, directory } = undefined,

    p_owner: permission = permission{},
    p_group: permission = permission{},
    p_other: permission = permission{},

    fn print(self: *fs_item) void {
        var permission_str: [9]u8 = undefined;
        if (self.p_owner.r == true) {
            permission_str[0] = 'r';
        }
        permission_str[0] = if (self.p_owner.r == true) 'r' else '-';
        permission_str[1] = if (self.p_owner.w == true) 'w' else '-';
        permission_str[2] = if (self.p_owner.x == true) 'x' else '-';
        permission_str[3] = if (self.p_group.r == true) 'r' else '-';
        permission_str[4] = if (self.p_group.w == true) 'w' else '-';
        permission_str[5] = if (self.p_group.x == true) 'x' else '-';
        permission_str[6] = if (self.p_other.r == true) 'r' else '-';
        permission_str[7] = if (self.p_other.w == true) 'w' else '-';
        permission_str[8] = if (self.p_other.x == true) 'x' else '-';
        permission_str[8] = 0;
        conprint("{s}\n", .{permission_str});
        //conprint("{s} X {s} {s} {d} {s} {s}", .{ permission_str, self.owner, self.group, self.size, self.date_modified, self.name });
    }
};

fn get_n_subfiles(pathname: []const u8) !usize {
    var dir = try std.fs.openIterableDirAbsolute(pathname, .{});
    defer dir.close();

    var iter = dir.iterate();

    var file_count: usize = 0;
    while (try iter.next()) |entry| {
        if (entry.kind == .File) file_count += 1;
    }

    return file_count;
}

fn print_all_items(pathname: []const u8) !void {
    var dir = try std.fs.openIterableDirAbsolute(pathname, .{});
    defer dir.close();

    var iter = dir.iterate();
    //print("iter={any}\n", .{iter});
    while (try iter.next()) |entry| {
        print("{s}\n", .{entry.name});
    }
}

fn append_directory_contents(pathname: []const u8, container: *std.ArrayList(fs_item)) !void {
    // TODO - convert pathname to absolute pathname
    var dir = try std.fs.openIterableDirAbsolute(pathname, .{});
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        var name = String.init(container.allocator);
        try name.concat(entry.name);

        var e = fs_item{
            .name = name,
        };

        //container.allocator.alloc(comptime T: type, n: usize)
        try container.append(e);
    }
}

fn append_cli_args(container: *std.ArrayList(String)) !void {
    var argiter = std.process.args();
    while (argiter.next()) |arg| {
        //_ = arg;
        var s = String.init(container.allocator);
        try s.concat(arg);
        try container.append(s);
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var args = std.ArrayList(String).init(allocator);
    try append_cli_args(&args);

    var buf0: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const cwd = try std.os.getcwd(&buf0);

    print("cwd    = '{s}'\n", .{cwd});
    print("nfiles = {any}\n", .{get_n_subfiles(cwd)});
    print("n_args = {d}\n", .{args.items.len});
    for (args.items) |a| {
        print("    {s}\n", .{a.str()});
    }
    // TODO - parse command line arguments

    var dirname = args.items[1];
    print("dirname = '{s}'\n", .{dirname.str()});
    //_ = dirname;
    // TODO - convert dirname to absolute path

    var dir_contents = std.ArrayList(fs_item).init(allocator);
    try append_directory_contents(dirname.str(), &dir_contents);

    for (dir_contents.items) |item| {
        print("    {s}\n", .{item.name.str()});
    }

    var testfile: fs_item = undefined; //fs_item{};
    testfile.p_owner.r = true;
    testfile.p_owner.w = true;
    testfile.p_owner.x = true;
    testfile.p_group.r = true;
    testfile.p_group.w = false;
    testfile.p_group.x = true;
    testfile.p_other.r = true;
    testfile.p_other.w = false;
    testfile.p_other.x = false;
    testfile.print();

    try print_all_items(cwd);
    //    try stdout.print("Hello, {s}!\n", .{"world"});

}
