const std = @import("std");
const min = std.math.min;
const max = std.math.max;
const os = std.os;

pub const u8str = struct {
    pub fn lessThan(context: void, a: []const u8, b: []const u8) bool {
        _ = context;
        var na = a.len;
        var nb = b.len;
        var imax: usize = min(na, nb);
        for (0..imax) |i| {
            var ca = a[i];
            var cb = b[i];
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

    pub fn startsWith(str: []const u8, prefix: []const u8) bool {
        if (prefix.len > str.len) {
            return false;
        }
        //return true;
        return std.mem.eql(u8, str[0..prefix.len], prefix);
    }

    pub fn countChar(str: []const u8, character: u8) u32 {
        var count: u32 = 0;
        for (0..str.len) |i| {
            count += @boolToInt(str[i] == character);
        }
        return count;
    }

    pub fn has_space(str: []const u8) bool {
        for (str) |c| {
            if (char.isSpace(c)) {
                return true;
            }
        }
        return false;
    }
};

pub const char = struct {
    pub fn isAlpha(arg: u8) bool {
        return switch (arg) {
            'a'...'z', 'A'...'Z' => true,
            else => false,
        };
    }
    pub fn isDigit(arg: u8) bool {
        return switch (arg) {
            '0'...'9' => true,
            else => false,
        };
    }
    pub fn isOctal(arg: u8) bool {
        return switch (arg) {
            '0'...'7' => true,
            else => false,
        };
    }
    pub fn isHex(arg: u8) bool {
        return switch (arg) {
            '0'...'9', 'a'...'f', 'A'...'F' => true,
            else => false,
        };
    }
    pub fn isAlnum(arg: u8) bool {
        return isAlpha(arg) or isDigit(arg);
    }
    // pub fn isprintable(arg: u8) bool {
    //     _ = arg;
    // }
    pub fn isSpace(arg: u8) bool {
        return switch (arg) {
            ' ', '\t' => true,
            else => false,
        };
    }

    pub fn getDecimalValue(arg: u8) u8 {
        switch(arg){
            '0'...'9' => { return arg - '0'; },
            else => { return 0; },
        }
    }
    pub fn getHexValue(arg: u8) u8 {
        switch(arg){
            '0'...'9' => { return arg - '0'; },
            'a'...'f' => { return arg - 'a' + 10; },
            'A'...'F' => { return arg - 'A' + 10; },
            else => { return 0; },
        }

    }
    pub fn getOctalValue(arg: u8) u8 {
        switch(arg){
            '0'...'7' => { return arg - '0'; },
            else => { return 0; },
        }

    }
};

pub const terminal = struct {
    pub fn getSize() !Vec2i {
        var ws: os.linux.winsize = undefined;
        var ret = os.linux.ioctl(os.STDOUT_FILENO, os.linux.T.IOCGWINSZ, @ptrToInt(&ws));
        if (ret == -1) {
            return error.ioctl;
        }
        return Vec2i{ .x = ws.ws_col, .y = ws.ws_row };
    }
};

pub const Vec2i = struct { x: i32 = 0, y: i32 = 0 };

pub fn gnomeSort(comptime T: type, items: []T, context: anytype, comptime lessThan: fn (context: @TypeOf(context), lhs: T, rhs: T) bool) void {
    var n = items.len;

    //std.sort.insertionSort(comptime T: type, items: []T, context: anytype, comptime lessThan: fn(context:@TypeOf(context), lhs:T, rhs:T)bool)
    var pos: usize = 0;
    while (pos < n) {
        if (pos == 0 or !lessThan({}, items[pos], items[pos - 1])) {
            pos += 1;
        } else {
            var temp: T = items[pos];
            items[pos] = items[pos - 1];
            items[pos - 1] = temp;
            pos -= 1;
        }
    }
}