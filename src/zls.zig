const cli = @import("./zcorecommon/cli.zig");
const util = @import("./zcorecommon/util.zig");
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

fn has_substr(str: []const u8, substr: []const u8) bool {
    return std.mem.indexOf(u8, str, substr) != null;
}

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

fn get_directory_contents(pathname: []const u8, alloc: std.mem.Allocator) !*std.ArrayList([]const u8) {
    var dir = try std.fs.openIterableDirAbsolute(pathname, .{});
    var iter = dir.iterate();

    var list: *std.ArrayList([]const u8) = try alloc.create(std.ArrayList([]const u8));
    list.* = std.ArrayList([]const u8).init(alloc);
    while (try iter.next()) |entry| {
        var strcpy: []u8 = try alloc.alloc(u8, entry.name.len);
        @memcpy(strcpy, entry.name);
        try list.append(strcpy);
    }
    return list;
}


fn simple_print(dir_contents: *const std.ArrayList([]const u8)) void {
    for (dir_contents.items) |fsi| {
        if(has_substr(fsi, " ")){
            print("'{s}'\n", .{fsi});
        } else {
            print("{s}\n", .{fsi});
        }
    }
}

fn contains_str_with_space(str_list: [][]const u8) bool {
    for (str_list) |str| {
        if (has_substr(str, " ")) {
            return true;
        }
    }
    return false;
}

fn calc_longest_string(str_list: [][]const u8) usize {
    if (str_list.len == 0) {
        return 0;
    }

    var width: usize = str_list[0].len;
    for (str_list) |str| {
        width = @max(width, str.len);
    }
    return width;
}

fn calc_shortest_string(str_list: [][]const u8) usize {
    if (str_list.len == 0) {
        return 0;
    }

    var width: usize = str_list[0].len;
    for (str_list) |str| {
        width = @min(width, str.len);
    }
    return width;
}

fn calc_print_columns(w_console: usize, dir_contents: *const std.ArrayList([]const u8)) usize {
    //var w_console: usize = 80;
    // TODO - find a way to interrogate actual console width

    var namelen_max = calc_longest_string(dir_contents.items);
    var namelen_min = calc_shortest_string(dir_contents.items);

    // assume 1x longest name and the rest are shortest
    // use 2-char padding for quote-characters (one on each side)
    // use 1x space between
    var ncols_max: usize = (w_console - namelen_max - 2) / (namelen_min + 3);
    var ncols_min: usize = 1;

    if (ncols_min >= ncols_max) {
        return 1;
    }

    var process_spaces = false;
    for (dir_contents.items) |e| {
        if (has_substr(e, " ")) {
            process_spaces = true;
            break;
        }
    }

    var len_wrap: usize = if (process_spaces) 2 else 0;
    var len_colsep: usize = if (process_spaces) 1 else 2;

    var nitems = dir_contents.items.len;
    var ncols: usize = 1;
    for (0..ncols_max) |e| {
        const cols = ncols_max - e;
        var w_line_max: usize = 0;
        var nrows = nitems / cols + @intFromBool((nitems % cols) > 0);
        for (0..cols) |i| {
            const is: usize = @min(i * nrows, dir_contents.items.len);
            const ie: usize = @min(is + nrows, dir_contents.items.len);
            const longest = calc_longest_string(dir_contents.items[is..ie]);
            w_line_max += longest + len_wrap; // add wrapping
        }
        w_line_max += cols + len_colsep; // add space between each column
        if (w_line_max <= w_console) {
            ncols = cols;
            break;
        }
    }

    return ncols;
}

const fs_column = struct {
    max_width: usize,
    has_space: bool,
};

const fs_row = struct {
    items: [][]const u8,
};

const fs_grid = struct {
    nitems: usize,
    alloc: std.mem.Allocator,

    columns: []fs_column,
    rows: []fs_row,

    fn init(dir_contents: *const std.ArrayList([]const u8), ncols: usize, alloc: std.mem.Allocator) !fs_grid {
        var ret: fs_grid = undefined;
        ret.alloc = alloc;
        ret.nitems = dir_contents.items.len;

        var nrows = ret.nitems / ncols + @intFromBool((ret.nitems % ncols) > 0);
        ret.columns = try ret.alloc.alloc(fs_column, ncols);
        ret.rows = try ret.alloc.alloc(fs_row, nrows);

        // fill grid
        for (0..nrows) |row| {
            var rowcols: usize = if (row >= ret.nitems % nrows) ncols else ncols - 1;
            ret.rows[row].items = try ret.alloc.alloc([]const u8, rowcols);
            for (0..rowcols) |col| {
                var i = row + nrows * col;
                if (i < ret.nitems) {
                    ret.rows[row].items[col] = dir_contents.items[i];
                } else {
                    ret.rows[row].items[col] = "";
                }
            }
        }

        // extract column data
        for (0..ncols) |col| {
            var col_start = @min(col * nrows, dir_contents.items.len);
            var col_end = @min(col_start + nrows, dir_contents.items.len);

            var col_has_space = contains_str_with_space(dir_contents.items[col_start..col_end]);
            var col_max_width = calc_longest_string(dir_contents.items[col_start..col_end]);

            ret.columns[col].max_width = col_max_width;
            ret.columns[col].has_space = col_has_space;
        }

        return ret;
    }

    pub fn deinit(self: *fs_grid) void {
        _ = self;
    }

    pub fn print(self: *fs_grid) void {
        for (self.rows) |row| {
            for (0..row.items.len) |i| {
                var col = self.columns[i];
                var wrapchar: []const u8 = "";
                if (col.has_space) {
                    if (has_substr(row.items[i], " ")) {
                        wrapchar = "'";
                    } else {
                        wrapchar = " ";
                    }
                }
                conprint("{s}{s}{s}", .{ wrapchar, row.items[i], wrapchar });
                if (i < row.items.len - 1) {
                    // print padding only for 'not-last' column
                    for (0..col.max_width - row.items[i].len) |j| {
                        _ = j;
                        conprint("{c}", .{' '});
                    }

                    var col_sep = if (self.columns[i + 1].has_space) "  " else "   ";
                    conprint("{s}", .{col_sep});
                }
            }
            conprint("\n", .{});
        }
    }
};

fn print_in_columns(ncols: usize, dir_contents: *const std.ArrayList([]const u8)) void {
    var nitems = dir_contents.items.len;
    var nrows = nitems / ncols + @intFromBool((nitems % ncols) > 0);

    var process_spaces = false;
    for (dir_contents.items) |e| {
        if (has_substr(e, " ")) {
            process_spaces = true;
            break;
        }
    }
    var wrapchar_nospace = if (process_spaces) " " else "";
    var column_separator = if (process_spaces) " " else "  ";

    // naive implementation, relies on calling get_longest_string nitems times
    for (0..nrows) |row| {
        for (0..ncols) |col| {
            var i = row + nrows * col;
            if (i >= nitems) {
                continue;
            }

            var col_start = @min(col * nrows, dir_contents.items.len);
            var col_end = @min(col_start + nrows, dir_contents.items.len);

            var wrapchar = wrapchar_nospace;
            if (has_substr(dir_contents.items[i], " ")) {
                wrapchar = "\"";
            }

            print("{s}{s}", .{ wrapchar, dir_contents.items[i] });
            if (col < ncols - 1) {
                // only apply padding to 'not-last' column
                var str_pad_target = calc_longest_string(dir_contents.items[col_start..col_end]);
                print("{s}", .{wrapchar});
                for (0..str_pad_target - dir_contents.items[i].len) |_| {
                    print(" ", .{});
                }
                print("{s}", .{column_separator});
            }
        }
        print("\n", .{});
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var args = std.ArrayList([]const u8).init(allocator);
    try cli.args.appendToArrayList(&args, allocator);
    var dirname = args.items[1];

    var flagmap = std.mem.zeroes([256]bool);
    for (args.items) |arg| {
        if (arg.len > 1 and std.mem.startsWith(u8, arg, "-") and std.mem.count(u8, arg, "-") == 1) {
            var is_all_alpha: bool = true;
            for (arg[1..]) |c| {
                is_all_alpha = is_all_alpha and std.ascii.isAlphabetic(c);
            }
            if (!is_all_alpha) {
                continue;
            }
            for (arg[1..]) |c| {
                flagmap[c] = true;
            }
        }
    }

    // TODO - parse command options
    //          -l = long print
    //          -h = display usage string

    // TODO - find most likely argument that describes path
    // TODO - convert dirname to absolute path

    var keep_all: bool = flagmap['a'] or flagmap['A'];
    var keep_all_extra: bool = flagmap['A'];
    _ = keep_all_extra;
    // get directory contents
    var dir_contents: *std.ArrayList([]const u8) = try get_directory_contents(dirname, allocator);
    var dir_contents_filt: std.ArrayList([]const u8) = undefined;
    dir_contents_filt = try std.ArrayList([]const u8).initCapacity(allocator, dir_contents.items.len);

    for (dir_contents.items) |entry| {
        if (keep_all) {
            try dir_contents_filt.append(entry);
        } else if (!std.mem.startsWith(u8, entry, ".")) {
            try dir_contents_filt.append(entry);
        }
    }

    //std.sort.sort(String, dir_contents.items, {}, stringLessThan);
    util.gnomeSort([]const u8, dir_contents_filt.items, {}, util.u8str.lessThan);
    // TODO - filtering per -a or -A

    var w_console: usize = 80;
    // TODO - get actual console width
    var ncols = calc_print_columns(w_console, &dir_contents_filt);

    var grid = try fs_grid.init(&dir_contents_filt, ncols, allocator);
    grid.print();
}
