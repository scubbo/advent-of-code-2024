const std = @import("std");
const print = std.debug.print;

const expect = @import("std").testing.expect;

test "Len of an iterator is not the same as size" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = std.AutoHashMap(u8, u8).init(allocator);
    try map.put('a', 'b');
    try map.put('c', 'd');
    try map.put('e', 'f');

    var keyIterator = map.keyIterator();
    const length = keyIterator.len;
    var counted_length: usize = 0;
    while (keyIterator.next()) |_| {
        counted_length += 1;
    }
    print("DEBUG - length is {} and counted_length is {}\n", .{ length, counted_length });
    try expect(length == counted_length);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var list = std.ArrayList(u8).init(allocator);
    try list.append('h');
    try list.append('e');
    try list.append('l');
    try list.append('l');
    try list.append('o');
    for (list.items) |char| {
        print("{c}", .{char});
    }
    list.deinit();
}

fn doIt(string: *const [3:0]u8) *const [9:0]u8 {
    return "prefix" ++ string;
}
