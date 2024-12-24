const std = @import("std");
const print = std.debug.print;

test "Demo accumulation" {
    const accumulated = try accumulate();
    print("DEBUG - accumulated values are {any}\n", .{accumulated});
}

fn accumulate() ![]u32 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var list = std.ArrayList(u32).init(allocator);
    defer list.deinit();
    try list.append(1);
    try list.append(2);
    try list.append(3);

    const response = try allocator.alloc(u32, list.items.len);
    @memcpy(response, list.items);
    return response;
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

const expect = @import("std").testing.expect;
