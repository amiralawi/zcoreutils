const std = @import("std");

const util = @import("./util.zig");

pub const name = "zcoreutils";
pub const version = "0.0.3h";
pub const author = "Amir Alawi";
pub const copyright_year = "2023";

pub const license = @embedFile("LICENSE");
pub const license_short = util.u8str.sliceLineStrip(license);

pub const EXIT_FAILURE: u8 = 1;
pub const EXIT_SUCCESS: u8 = 0;

pub fn print_exe_version(writer: std.fs.File.Writer, compiled_exe_name: []const u8) !void {
    try writer.print(
        \\{s} ({s}) {s}
        \\Copyright (C) {s} Amir Alawi.
        \\License: {s}.
        \\
        \\Written by Amir Alawi.
        \\
    , .{ compiled_exe_name, name, version, copyright_year, license_short });
}
