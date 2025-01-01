const std = @import("std");
const print = std.debug.print;

const expect = @import("std").testing.expect;

test ".toOwnedSlice does not seem to make deinit unnecessary" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var listOfLists = std.ArrayList([]u32).init(allocator);
    try listOfLists.append(try buildAList(0, allocator));
    try listOfLists.append(try buildAList(1, allocator));

    const outer_slice = try listOfLists.toOwnedSlice();
    print("{any}\n", .{outer_slice});
    for (outer_slice) |inner_slice| {
        allocator.free(inner_slice);
    }
    allocator.free(outer_slice);
}

fn buildAList(val: u32, allocator: std.mem.Allocator) ![]u32 {
    var list = std.ArrayList(u32).init(allocator);

    try list.append(val);

    return list.toOwnedSlice();
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
