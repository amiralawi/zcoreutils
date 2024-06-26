// const std = @import("std");
// const os = std.os;

const std = @import("std");
const builtin = @import("builtin");
const os = std.os;
const io = std.io;
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;
const windows = os.windows;
const Os = std.builtin.Os;
const maxInt = std.math.maxInt;
const is_windows = builtin.os.tag == .windows;

pub const u8str = struct {
    pub const hash = struct {
        pub fn pop32(str: []const u8) u32 {
            // taken from:
            // https://stackoverflow.com/questions/2351087/what-is-the-best-32bit-hash-function-for-short-strings-tag-names
            //
            // which is taken from:
            // The Practice of Programming (HASH TABLES, pg. 57)

            // Empirically, the values 31 and 37 have proven to be good choices for the
            // multiplier in a hash function for ASCII strings.
            const multiplier = 31;

            var h: u32 = 0;
            for (str) |c| {
                h = multiplier *% h +% c;
            }
            return h;
        }
    };

    pub fn lessThan(context: void, a: []const u8, b: []const u8) bool {
        _ = context;
        const na = a.len;
        const nb = b.len;
        const imax: usize = @min(na, nb);
        for (0..imax) |i| {
            const ca = a[i];
            const cb = b[i];
            if (ca < cb) {
                return true;
            } else if (ca > cb) {
                return false;
            }
        }
        //two strings are equal so far
        if (na < nb) return true;
        return false;
    }

    pub fn cmp(a: []const u8, b: []const u8) bool {
        // opposite (now correct) polarity to c-strcmp
        return std.mem.eql(u8, a, b);
    }

    pub fn startsWith(str: []const u8, prefix: []const u8) bool {
        _ = prefix;
        _ = str;
        @compileError("deprecated - use std.mem.startsWith(u8, haystack, needle)");
        // if (prefix.len > str.len) {
        //     return false;
        // }
        // //return true;
        // return std.mem.eql(u8, str[0..prefix.len], prefix);
    }

    // pub fn has_space(str: []const u8) bool {
    //     for (str) |c| {
    //         if (std.ascii.isWhitespace(c)) {
    //             return true;
    //         }
    //     }
    //     return false;
    // }

    pub fn findChar(str: []const u8, ch: u8) isize {
        for (str, 0..) |e, i| {
            if (e == ch) {
                return i;
            }
        }
        return -1;
    }

    pub fn rfindChar(str: []const u8, ch: u8) isize {
        var i = str.len;
        while (i > 0) {
            i -= 1;
            if (str[i] == ch) {
                return @intCast(i);
            }
        }
        return -1;
    }

    pub fn sliceLine(str: []const u8) []const u8 {
        for (str, 1..) |e, i| {
            if (e == '\n') {
                return str[0..i];
            }
        }
        return str;
    }
    pub fn sliceStrip(str: []const u8) []const u8 {
        var str_rstrip = sliceRstrip(str);
        for (str_rstrip, 0..) |e, i| {
            if (!std.ascii.isWhitespace(e)) {
                return str_rstrip[i..];
            }
        }
        return str_rstrip[0..0];
    }
    pub fn sliceRstrip(str: []const u8) []const u8 {
        var i: usize = str.len;
        while (i > 0) {
            i -= 1;
            if (!std.ascii.isWhitespace(str[i])) {
                return str[0 .. i + 1];
            }
        }
        return str[0..0];
    }
    pub fn sliceLineRstrip(str: []const u8) []const u8 {
        const line = sliceLine(str);
        return sliceRstrip(line);
    }
    pub fn sliceLineStrip(str: []const u8) []const u8 {
        const line = sliceLineRstrip(str);
        return sliceStrip(line);
    }
};

pub const char = struct {
    pub fn isOctal(arg: u8) bool {
        return switch (arg) {
            '0'...'7' => true,
            else => false,
        };
    }

    pub fn getDecimalValue(arg: u8) u8 {
        switch (arg) {
            '0'...'9' => {
                return arg - '0';
            },
            else => {
                return 0;
            },
        }
    }
    pub fn getHexValue(arg: u8) u8 {
        switch (arg) {
            '0'...'9' => {
                return arg - '0';
            },
            'a'...'f' => {
                return arg - 'a' + 10;
            },
            'A'...'F' => {
                return arg - 'A' + 10;
            },
            else => {
                return 0;
            },
        }
    }
    pub fn getOctalValue(arg: u8) u8 {
        switch (arg) {
            '0'...'7' => {
                return arg - '0';
            },
            else => {
                return 0;
            },
        }
    }
};

pub const terminal = struct {
    pub fn getSize() !Vec2i {
        var ws: os.linux.winsize = undefined;
        const ret = os.linux.ioctl(os.STDOUT_FILENO, os.linux.T.IOCGWINSZ, @intFromPtr(&ws));
        if (ret == -1) {
            return error.ioctl;
        }
        return Vec2i{ .x = ws.ws_col, .y = ws.ws_row };
    }
};

pub const Vec2i = struct { x: i32 = 0, y: i32 = 0 };

pub fn gnomeSort(comptime T: type, items: []T, context: anytype, comptime lessThan: fn (context: @TypeOf(context), lhs: T, rhs: T) bool) void {
    const n = items.len;

    //std.sort.insertionSort(comptime T: type, items: []T, context: anytype, comptime lessThan: fn(context:@TypeOf(context), lhs:T, rhs:T)bool)
    var pos: usize = 0;
    while (pos < n) {
        if (pos == 0 or !lessThan({}, items[pos], items[pos - 1])) {
            pos += 1;
        } else {
            const temp: T = items[pos];
            items[pos] = items[pos - 1];
            items[pos - 1] = temp;
            pos -= 1;
        }
    }
}

