const std = @import("std");
const print = std.debug.print;

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

const expect = @import("std").testing.expect;

test {
    for (doIt("foo")) |char| {print("{c}", .{char});}
    print("\n", .{});
    for ("prefixfoo") |char| {print("{c}", .{char});}
    print("\n", .{});
    try expect(std.mem.eql(u8, doIt("foo"), "prefixfoo"));
}