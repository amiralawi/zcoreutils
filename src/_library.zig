const std = @import("std");
const util = @import("./util.zig");

pub const name = "zcoreutils";
pub const version = "0.0.1";
pub const author = "Amir Alawi";
pub const copyright_year = "2023";

pub const license = @embedFile("LICENSE");
pub const license_short = util.u8str.sliceLineStrip(license);