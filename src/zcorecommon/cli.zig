const std = @import("std");

pub const args = struct{
    pub fn appendToArrayList(container: *std.ArrayList([]const u8), allocator: std.mem.Allocator) !void {
        var argiter = try std.process.argsWithAllocator(allocator);
        while (argiter.next()) |arg| {
            try container.append(arg);
        }
    }
};