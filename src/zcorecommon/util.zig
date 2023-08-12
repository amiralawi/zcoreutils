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
    pub fn lessThan(context: void, a: []const u8, b: []const u8) bool {
        _ = context;
        var na = a.len;
        var nb = b.len;
        var imax: usize = @min(na, nb);
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

    pub fn cmp(a: []const u8, b:[]const u8) bool {
        // opposite (now correct) polarity to c-strcmp
        return std.mem.eql(u8, a, b);
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
        for(str) |ch| {
            count += @intFromBool(ch == character);
        }
        return count;
    }
    pub fn hasChar(str: []const u8, character: u8) bool {
        for(str) |ch| {
            if(ch == character){
                return true;
            }
        }
        return false;
    }

    pub fn has_space(str: []const u8) bool {
        for (str) |c| {
            if (char.isSpace(c)) {
                return true;
            }
        }
        return false;
    }

    pub fn findChar(str: []const u8, ch: u8) usize {
        for(str, 0..) |e, i| {
            if(e == ch){
                return i;
            }
        }
        return -1;
    }

    pub fn sliceLine(str: []const u8) []const u8 {
        for(str, 1..) |e, i| {
            if(e == '\n'){
                return str[0..i];
            }
        }
        return str;
    }
    pub fn sliceStrip(str: []const u8) []const u8 {
        var str_rstrip = sliceRstrip(str);
        for(str_rstrip, 0..) |e, i| {
            if(!char.isSpace(e)){
                return str_rstrip[i..];
            }
        }
        return str_rstrip[0..0];
    }
    pub fn sliceRstrip(str: []const u8) []const u8 {
        var i: usize = str.len;
        while (i > 0) {
            i -= 1;
            if(!char.isSpace(str[i])){
                return str[0..i+1];
            }
        }
        return str[0..0];
    }
    pub fn sliceLineRstrip(str: []const u8) []const u8 {
        var line = sliceLine(str);
        return sliceRstrip(line);
    }
    pub fn sliceLineStrip(str: []const u8) []const u8 {
        var line = sliceLineRstrip(str);
        return sliceStrip(line);
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
    pub fn isSpace(arg: u8) bool {
        return switch (arg) {
            ' ', '\t', '\r', '\n' => true,
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
        var ret = os.linux.ioctl(os.STDOUT_FILENO, os.linux.T.IOCGWINSZ, @intFromPtr(&ws));
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

pub const File = struct{
    pub const UpdateTimeSV = enum(isize) { ignore, UTIME_NOW, UTIME_OMIT, };
    pub const SPECIAL_VALUE_UTIME_NOW  = 0x3fffffff;
    pub const SPECIAL_VALUE_UTIME_OMIT = 0x3ffffffe;
    pub fn updateTimesSpecial(
        file: std.fs.File,
        /// access timestamp in nanoseconds
        atime: i128,
        /// last modification timestamp in nanoseconds
        mtime: i128,
        atime_sv: UpdateTimeSV,
        mtime_sv: UpdateTimeSV,
    ) std.fs.File.UpdateTimesError!void {
        if (builtin.os.tag == .windows) {
            const atime_ft = windows.nanoSecondsToFileTime(atime);
            const mtime_ft = windows.nanoSecondsToFileTime(mtime);
            return windows.SetFileTime(file.handle, null, &atime_ft, &mtime_ft);
        }
        var times = [2]os.timespec{
            os.timespec{
                .tv_sec = math.cast(isize, @divFloor(atime, std.time.ns_per_s)) orelse maxInt(isize),
                .tv_nsec = math.cast(isize, @mod(atime, std.time.ns_per_s)) orelse maxInt(isize),
            },
            os.timespec{
                .tv_sec = math.cast(isize, @divFloor(mtime, std.time.ns_per_s)) orelse maxInt(isize),
                .tv_nsec = math.cast(isize, @mod(mtime, std.time.ns_per_s)) orelse maxInt(isize),
            },
        };

        switch(atime_sv){
            .UTIME_NOW  => { times[0].tv_nsec = SPECIAL_VALUE_UTIME_NOW;  },
            .UTIME_OMIT => { times[0].tv_nsec = SPECIAL_VALUE_UTIME_OMIT; },
            .ignore     => {},
        }
        switch(mtime_sv){
            .UTIME_NOW  => { times[1].tv_nsec = SPECIAL_VALUE_UTIME_NOW;  },
            .UTIME_OMIT => { times[1].tv_nsec = SPECIAL_VALUE_UTIME_OMIT; },
            .ignore     => {},
        }
        try os.futimens(file.handle, &times);
    }

};