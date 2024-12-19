const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var hashMap = std.AutoHashMap(u32, u32).init(allocator);

    try hashMap.put(2, 5);
    try hashMap.put(1, 35);
    try hashMap.put(4, 20);

    const iter = hashMap.keyIterator();
    while (try iter.next()) |key| {
        print("{}\n", .{key});
    }
}