const std = @import("std");

pub const OptionArgumentType = enum { none, required, optional };
pub const ParseError = error{
    InvalidLongOption,
    InvalidShortOption,
    UnexpectedArgument,
};

pub fn pop32Hash(str: []const u8) u32 {
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

pub const Option = struct {
    short: ?u8 = null,
    long: ?[]const u8 = null,
    help: []const u8,
    action: ?*const fn (context: *anyopaque) void = null,

    flag: bool = false,
    count: usize = 0,
    value: ?[]const u8 = null,
    argument: OptionArgumentType = .none,
};

pub fn Parser(comptime T: type) type {
    const _longopts = getLongOptions(T);

    const _shortopts = getShortOptions(T);
    const allopts = getAllOptions(T);

    // calc for future short-search optimization
    comptime var _short_min: u8 = 0;
    comptime var _short_max: u8 = 0;
    for (_shortopts) |so| {
        _short_min = @min(_short_min, so.short);
        _short_max = @max(_short_max, so.short);
    }

    // calc for future hash-search optimization
    comptime var _long_minlen: usize = if (_longopts.len > 0) _longopts[0].long.len else 0;
    comptime var _long_maxlen: usize = if (_longopts.len > 0) _longopts[0].long.len else 0;
    for (_longopts) |lo| {
        _long_minlen = @min(_long_minlen, lo.long.len);
        _long_maxlen = @max(_long_maxlen, lo.long.len);
    }

    //
    // generate helpstr
    //

    // "  -X, --longopt[=ARG]  begin help string"
    const ncols = 80;
    const size_prefix = helpstr_prefix_size(&_shortopts, &_longopts);
    const helpstr_cols = ncols - size_prefix;

    comptime var helpstr_size: usize = 0;
    comptime var nlines: usize = 0;
    for (allopts) |opt| {
        nlines += 1;
        if (opt.help.len == helpstr_cols) {
            helpstr_size += ncols;
            continue;
        }

        const helpstr_full_lines = opt.help.len / helpstr_cols;
        const helpstr_remainder = opt.help.len % helpstr_cols;

        nlines += helpstr_full_lines;
        helpstr_size += helpstr_full_lines * ncols + (size_prefix + helpstr_remainder);
    }
    helpstr_size += (nlines * 2); // "\r\n"

    comptime var _helpstr: [helpstr_size]u8 = undefined;
    comptime var _i: usize = 0;

    for (allopts) |opt| {
        const istart = _i;

        _i += hsPrint(_helpstr[_i..], "  ", .{});
        if (_shortopts.len > 0) {
            if (opt.short) |short| {
                _i += hsPrint(_helpstr[_i..], "-{c}", .{short});
            } else {
                _i += hsPrint(_helpstr[_i..], "  ", .{});
            }
        }

        if (_shortopts.len > 0 and _longopts.len > 0) {
            const ls_sep = if (opt.short != null and opt.long != null) ',' else ' ';
            _i += hsPrint(_helpstr[_i..], "{c} ", .{ls_sep});
        }

        if (_longopts.len > 0) {
            if (opt.long) |long| switch (opt.argument) {
                .none => {
                    _i += hsPrint(_helpstr[_i..], "--{s}  ", .{long});
                },
                .required => {
                    _i += hsPrint(_helpstr[_i..], "--{s}=ARG  ", .{long});
                },
                .optional => {
                    _i += hsPrint(_helpstr[_i..], "--{s}[=ARG]  ", .{long});
                },
            };
        }

        const n_fill = size_prefix - (_i - istart);
        for (n_fill) |_| {
            _i += hsPrint(_helpstr[_i..], " ", .{});
        }

        const helpstr_lines: usize = opt.help.len / helpstr_cols;
        const helpstr_remainder = opt.help.len % helpstr_cols;
        var _j = 0;
        for (0..helpstr_lines) |_| {
            _i += hsPrint(_helpstr[_i..], "{s}\r\n", .{opt.help[_j .. _j + helpstr_cols]});
            _j += helpstr_cols;

            if (helpstr_remainder > 0) {
                for (size_prefix) |_| {
                    _i += hsPrint(_helpstr[_i..], " ", .{});
                }
            }
        }
        _i += hsPrint(_helpstr[_i..], "{s}\r\n", .{opt.help[_j..opt.help.len]});
    }

    return struct {
        const Self = @This();

        pub const longopts = _longopts;
        pub const shortopts = _shortopts;

        const short_min = _short_min;
        const short_max = _short_max;

        pub const helpstr: [helpstr_size]u8 = _helpstr;

        pub const long_minlen = _long_minlen;
        pub const long_maxlen = _long_maxlen;

        option_expecting_argument: ?*Option = null,
        lastshort: u8 = undefined,
        ignore_options: bool = false,
        context: *T,

        // public interface
        pub fn init(context: *T) Self {
            return .{ .context = context };
        }

        pub fn printUsage(context: *anyopaque) void {
            _ = context;
            std.debug.print("{s}", .{Self.helpstr});
        }

        pub fn parse(self: *Self, str: []const u8) ParseError!bool {
            // returns true if recognized option, else false (positional argument?)

            if (self.option_expecting_argument) |oea| {
                oea.value = str;
                oea.flag = true;
                oea.count += 1;
                if (oea.action) |action| {
                    action(self.context);
                }

                self.option_expecting_argument = null;
                return true;
            }

            if (self.ignore_options) {
                return false;
            } else if (std.mem.startsWith(u8, str, "--")) {
                return self.test_longopt(str[2..]);
            } else if (std.mem.startsWith(u8, str, "-") and str.len > 1) {
                return self.test_shortopt(str[1..]);
            }
            return false;
        }

        // internal functions
        fn test_longopt(self: *Self, str: []const u8) ParseError!bool {
            if (str.len == 0) {
                self.ignore_options = false;
                return true;
            }

            if (str.len < long_minlen) {
                return ParseError.InvalidLongOption;
            }

            const niequals = std.mem.indexOfScalar(u8, str, '=');
            const i_opt_str = niequals orelse str.len;
            const argument_present = niequals != null;
            const opt_str: []const u8 = str[0..i_opt_str];

            if (opt_str.len > Self.long_maxlen) {
                return ParseError.InvalidLongOption;
            }

            const opt_arg: []const u8 = if (argument_present) str[i_opt_str + 1 .. str.len] else str[0..0];
            const hash = pop32Hash(opt_str);

            // old below
            // var argument_present = false;
            // var opt_str: []const u8 = str;
            // var arg_str: []const u8 = undefined;

            // const i_search: usize = @min(long_minlen, str.len);
            // const j_search: usize = @min(long_maxlen + 1, str.len);
            // const str_search: []const u8 = str[i_search..j_search];
            // for (str_search, i_search..) |ch, i| {
            //     if (ch == '=') {
            //         argument_present = true;
            //         opt_str = str[0..i];
            //         arg_str = str[i + 1 ..];
            //         break;
            //     }
            // }

            // if (opt_str.len > long_maxlen) {
            //     return ParseError.InvalidLongOption;
            // }

            if (self.find_longopt(opt_str, hash)) |optr| {
                if (argument_present) switch (optr.argument) {
                    .none => {
                        return ParseError.UnexpectedArgument;
                    },
                    .required, .optional => {
                        optr.value = opt_arg;
                    },
                } else if (optr.argument == .required) {
                    self.option_expecting_argument = optr;
                    optr.value = null;
                    return true;
                }

                optr.flag = true;
                optr.count += 1;
                if (optr.action) |action| {
                    action(self.context);
                }
                return true;
            }
            return false;
        }

        fn find_longopt(self: *Self, long: []const u8, hash: u32) ?*Option {
            inline for (longopts) |lod| {
                if (hash == lod.hash and std.mem.eql(u8, long, lod.long)) {
                    return &@field(self.context, lod.fieldname);
                }
            }
            return null;
        }

        fn find_shortopt(self: *Self, short: u8) ?*Option {
            if (short < Self.short_min or short > Self.short_max) {
                return null;
            }

            inline for (shortopts) |sod| {
                if (sod.short == short) {
                    return &@field(self.context, sod.fieldname);
                }
            }
            return null;
        }

        fn test_shortopt(self: *Self, str: []const u8) ParseError!bool {
            for (str, 0..) |ch, i| {
                if (self.find_shortopt(ch)) |optr| switch (optr.argument) {
                    .none => {
                        // default behavior
                        optr.flag = true;
                        optr.count += 1;
                        optr.value = null;
                        if (optr.action) |action| {
                            action(self.context);
                        }
                    },
                    .required => {
                        if (i == str.len - 1) {
                            self.option_expecting_argument = optr;
                            optr.value = null;
                        } else {
                            optr.flag = true;
                            optr.count += 1;
                            optr.value = str[i + 1 ..];
                            if (optr.action) |action| {
                                action(self.context);
                            }
                        }
                        return true;
                    },
                    .optional => {
                        if (i == str.len - 1) {
                            optr.flag = true;
                            optr.count += 1;
                            optr.value = null;
                            if (optr.action) |action| {
                                action(self.context);
                            }
                        } else {
                            optr.flag = true;
                            optr.count += 1;
                            optr.value = str[i + 1 ..];
                            if (optr.action) |action| {
                                action(self.context);
                            }
                        }
                        return true;
                    },
                } else {
                    return ParseError.InvalidShortOption;
                }
            }

            return true;
        }
    };
}

const ShortOptionDescriptor = struct {
    fieldname: []const u8,
    short: u8,
    action: ?*const fn (context: *anyopaque) void,
    help: []const u8,

    pub fn _lt_short(context: void, a: ShortOptionDescriptor, b: ShortOptionDescriptor) bool {
        _ = context;
        return a.short < b.short;
    }
};

const LongOptionDescriptor = struct {
    fieldname: []const u8,
    long: []const u8,
    action: ?*const fn (context: *anyopaque) void,
    help: []const u8,
    argument: OptionArgumentType,
    // TODO - hash
    hash: u32,
};

fn getNumShortOptions(comptime T: type) usize {
    var n: usize = 0;
    inline for (std.meta.fields(T)) |f| {
        if (f.default_value == null or f.type != Option) {
            continue;
        }
        const p: *const Option = @alignCast(@ptrCast(f.default_value.?));
        if (p.short != null) {
            n += 1;
        }
    }
    return n;
}

fn getNumLongOptions(comptime T: type) usize {
    var n: usize = 0;
    inline for (std.meta.fields(T)) |f| {
        if (f.default_value == null or f.type != Option) {
            continue;
        }
        const p: *const Option = @alignCast(@ptrCast(f.default_value.?));
        if (p.long != null) {
            n += 1;
        }
    }
    return n;
}

fn getNumAllOptions(comptime T: type) usize {
    var n: usize = 0;
    inline for (std.meta.fields(T)) |f| {
        if (f.default_value == null or f.type != Option) {
            continue;
        }
        n += 1;
    }
    return n;
}

fn getAllOptions(comptime T: type) [getNumAllOptions(T)]Option {
    var options: [getNumAllOptions(T)]Option = undefined;
    var n: usize = 0;
    inline for (std.meta.fields(T)) |f| {
        if (f.default_value == null or f.type != Option) {
            continue;
        }
        const p: *const Option = @alignCast(@ptrCast(f.default_value.?));
        options[n] = p.*;
        n += 1;
    }
    return options;
}

fn getShortOptions(comptime T: type) [getNumShortOptions(T)]ShortOptionDescriptor {
    var options: [getNumShortOptions(T)]ShortOptionDescriptor = undefined;

    var n: usize = 0;
    inline for (std.meta.fields(T)) |f| {
        if (f.default_value == null or f.type != Option) {
            continue;
        }
        const p: *const Option = @alignCast(@ptrCast(f.default_value.?));
        if (p.short) |ch| {
            options[n] = .{ .fieldname = f.name, .short = ch, .action = p.action, .help = p.help };
            n += 1;
        }
    }

    std.mem.sort(ShortOptionDescriptor, &options, {}, ShortOptionDescriptor._lt_short);

    return options;
}

fn getLongOptions(comptime T: type) [getNumLongOptions(T)]LongOptionDescriptor {
    // calls compileError if descriptor is invalid

    var options: [getNumLongOptions(T)]LongOptionDescriptor = undefined;

    var n: usize = 0;
    inline for (std.meta.fields(T)) |f| {
        if (f.default_value == null or f.type != Option) {
            continue;
        }
        const p: *const Option = @alignCast(@ptrCast(f.default_value.?));
        if (p.long) |str| {
            options[n] = .{ .fieldname = f.name, .long = str, .action = p.action, .help = p.help, .argument = p.argument, .hash = pop32Hash(str) };
            n += 1;
        }
    }

    return options;
}

fn Named(comptime T: type) type {
    return struct { name: []const u8, value: T };
}

fn helpstr_prefix_size(shortopts: []const ShortOptionDescriptor, longopts: []const LongOptionDescriptor) usize {
    const size_short: usize = if (shortopts.len > 0) 2 else 0;
    var size_long: usize = 0;
    for (longopts) |lod| {
        // --lod_size[=arg]
        var lod_size: usize = 2 + lod.long.len;
        if (lod.argument == .required) {
            lod_size += 4;
        } else if (lod.argument == .optional) {
            lod_size += 6;
        }
        size_long = @max(size_long, lod_size);
    }

    const size_sep: usize = if (shortopts.len > 0 and longopts.len > 0) 2 else 0;
    const size_prefix: usize = 2 + size_short + size_sep + size_long + 2;

    return size_prefix;
}

fn hsPrint(buf: []u8, comptime fmt: []const u8, args: anytype) usize {
    const wr_slice: []u8 = std.fmt.bufPrint(buf, fmt, args) catch {
        @compileError("hsPrint - nospaceleft");
    };
    return wr_slice.len;
}
