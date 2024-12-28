const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");

pub fn main() !void {
    const response = try part_one(false);
    print("{}\n", .{response});
}

const Point = struct { x: usize, y: usize };

fn part_one(is_test_case: bool) !usize {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("08", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);
    print("DEBUG - created data", .{});

    // In this problem I'm experimenting with not even parsing the input into lines, but just keeping a "line counter"
    // that is incremented whenever we hit a `\n` character
    var width: ?usize = null;
    var height: ?usize = null;
    var x: usize = 0;
    var y: usize = 0;
    var antennae = std.AutoHashMap(u8, std.ArrayList(Point)).init(allocator);
    defer antennae.deinit();

    for (data) |c| {
        print("DEBUG - checking {c} at {}, {}\n", .{ c, x, y });
        switch (c) {
            '\n' => {
                if (width == null) {
                    width = x;
                }
                x = 0;
                y += 1;
            },
            '.' => {
                x += 1;
            },
            else => {
                const point = Point{ .x = x, .y = y };
                // https://ziggit.dev/t/problem-with-hashmaps/7221 was helpful!
                var result = try antennae.getOrPut(c);
                if (!result.found_existing) {
                    result.value_ptr.* = std.ArrayList(Point).init(allocator);
                }
                try result.value_ptr.append(point);
                x += 1;
            },
        }
    }
    height = y; // No `+1` because the trailing newline will do that for us.
    print("DEBUG - height is {} and width is {}\n", .{ height.?, width.? });

    // Zig lacks a Set (https://github.com/ziglang/zig/issues/6919), so we abuse a HashMap to pretend
    var all_antinodes = std.AutoHashMap(Point, usize).init(allocator);
    defer all_antinodes.deinit();

    var it = antennae.valueIterator();
    while (it.next()) |v| {
        const node_pairs = try pairs(v.items, allocator);
        defer allocator.free(node_pairs);
        for (node_pairs) |node_pair| {
            const antinodes = try findAntinodes(node_pair, width.?, height.?, allocator);
            defer allocator.free(antinodes);
            for (antinodes) |antinode| {
                try all_antinodes.put(antinode, 1); // We don't actually need to put any value - just populating the key
            }
        }
        // allocator.free(v); <-- because we can't do this, there will still always be memory leaked :'(
    }

    var count: usize = 0;
    var antinode_iterator = all_antinodes.keyIterator();
    print("DEBUG - antinodes are:\n", .{});
    while (antinode_iterator.next()) |antinode| {
        print("{}\n", .{antinode});
        count += 1;
    }
    return count;
}

fn pairs(nodes: []Point, allocator: std.mem.Allocator) ![][2]Point {
    var output = std.ArrayList([2]Point).init(allocator);
    defer output.deinit();
    var a: usize = 0;
    while (a < nodes.len - 1) : (a += 1) {
        var b = a + 1;
        while (b < nodes.len) : (b += 1) {
            try output.append(.{ nodes[a], nodes[b] });
        }
    }
    return output.toOwnedSlice();
}

fn findAntinodes(nodes: [2]Point, width: usize, height: usize, allocator: std.mem.Allocator) ![]Point {
    var response = std.ArrayList(Point).init(allocator);
    defer response.deinit();

    if (2 * nodes[1].x >= nodes[0].x and 2 * nodes[1].y >= nodes[0].y) {
        const antiNode1 = Point{ .x = 2 * nodes[1].x - nodes[0].x, .y = 2 * nodes[1].y - nodes[0].y };
        if (antiNodeIsValid(antiNode1, width, height)) {
            try response.append(antiNode1);
        }
    }

    if (2 * nodes[0].x >= nodes[1].x and 2 * nodes[0].y >= nodes[1].y) {
        const antiNode2 = Point{ .x = 2 * nodes[0].x - nodes[1].x, .y = 2 * nodes[0].y - nodes[1].y };
        if (antiNodeIsValid(antiNode2, width, height)) {
            try response.append(antiNode2);
        }
    }

    return response.toOwnedSlice();
}

fn antiNodeIsValid(antiNode: Point, width: usize, height: usize) bool {
    // Don't technically need to check for >= 0 because that's already checked in `findAntinodes` (because otherwise
    // there would be integer overflow by daring to use a negative number :P ), but doesn't hurt to replicate it here -
    // otherwise a future reader might think we've forgotten it.
    return antiNode.x >= 0 and antiNode.y >= 0 and antiNode.x < width and antiNode.y < height;
}

const expect = std.testing.expect;

test "part_one" {
    const part_one_response = try part_one(true);
    print("DEBUG - part_one_response is {}\n", .{part_one_response});
    try expect(part_one_response == 14);
}
