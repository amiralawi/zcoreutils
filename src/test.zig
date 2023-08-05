const generic = @import("./zcorecommon/generic.zig");
const util = @import("./zcorecommon/util.zig");
const cli = @import("./zcorecommon/cli.zig");
const std = @import("std");
const stdout = std.io.getStdOut().writer();


// pub fn print_buffer_items(buf: *generic.ringBuffer(i32)) !void {
//     try stdout.print("buffer=(", .{});
//     var sep: []const u8 = "";
//     for(0..buf.size()) |i| {
//         var e = buf.peek(i);
//         if(e != null){
//             try stdout.print("{s}{?d}", .{sep, e});
//         }
//         sep = ", ";
//     }
//     try stdout.print(")\n", .{});
// }

pub fn print_buffer_items(buf: *generic.ringBuffer(i32)) !void {
    try stdout.print("buffer=(", .{});
    var sep: []const u8 = "";
    var items = buf.peekItems();
    while(items.next()) |e| {
        try stdout.print("{s}{?d}", .{sep, e});
        sep = ", ";
    }
    try stdout.print(")\n", .{});
}


pub fn main() !void {
    var rawbuf: [3]i32 = undefined;
    var ring = generic.ringBuffer(i32).init(&rawbuf);
    
    try stdout.print("start -> empty={} full={}\n", .{ring.isEmpty(), ring.isFull()});

    ring.write(5);
    try stdout.print("write(5) -> empty={} full={}\n", .{ring.isEmpty(), ring.isFull()});

    ring.write(-3);
    try stdout.print("write(-3) -> empty={} full={}\n", .{ring.isEmpty(), ring.isFull()});

    ring.write(1);
    try stdout.print("write(1) -> empty={} full={}\n", .{ring.isEmpty(), ring.isFull()});
    //var ring: generic.ringBuffer(i32) = undefined;
    //ring = generic.ringBuffer(i32).init(&rawbuf);
    try print_buffer_items(&ring);
    try stdout.print("read = {?d} -> empty={} full={}\n", .{ring.read(), ring.isEmpty(), ring.isFull()});
    try print_buffer_items(&ring);
    try stdout.print("read = {?d} -> empty={} full={}\n", .{ring.read(), ring.isEmpty(), ring.isFull()});
    try print_buffer_items(&ring);
    try stdout.print("read = {?d} -> empty={} full={}\n", .{ring.read(), ring.isEmpty(), ring.isFull()});
    try print_buffer_items(&ring);
    try stdout.print("read = {?d} -> empty={} full={}\n", .{ring.read(), ring.isEmpty(), ring.isFull()});
    try print_buffer_items(&ring);


    ring.write(5);
    try stdout.print("\nwrite(5) -> empty={} full={}\n", .{ring.isEmpty(), ring.isFull()});
    try print_buffer_items(&ring);

    ring.write(-3);
    try stdout.print("\nwrite(-3) -> empty={} full={}\n", .{ring.isEmpty(), ring.isFull()});
    try print_buffer_items(&ring);

    ring.write(1);
    try stdout.print("\nwrite(1) -> empty={} full={}\n", .{ring.isEmpty(), ring.isFull()});
    try print_buffer_items(&ring);
    
    _ = ring.writeForce(66);
    try stdout.print("\nwriteForce(66) -> empty={} full={}\n", .{ring.isEmpty(), ring.isFull()});
    try print_buffer_items(&ring);



    try stdout.print("\n", .{});

}