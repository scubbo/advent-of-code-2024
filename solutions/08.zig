const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");

pub fn main() !void {
    const response = try part_two(false);
    print("{}\n", .{response});
}

const Point = struct { x: u16, y: u16 };

fn part_one(is_test_case: bool) !usize {
    return execute(is_test_case, findAntinodes);
}

fn execute(is_test_case: bool, antinode_determination_function: fn (nodes: [2]Point, width: usize, height: usize, allocator: std.mem.Allocator) anyerror![]Point) !usize {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("08", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);
    print("DEBUG - created data\n", .{});

    // In this problem I'm experimenting with not even parsing the input into lines, but just keeping a "line counter"
    // that is incremented whenever we hit a `\n` character
    var width: ?usize = null;
    var height: ?usize = null;
    var x: u16 = 0;
    var y: u16 = 0;
    var antennae = std.AutoHashMap(u8, std.ArrayList(Point)).init(allocator);
    defer antennae.deinit();

    for (data) |c| {
        // print("DEBUG - checking {c} at {}, {}\n", .{ c, x, y });
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
                    defer result.value_ptr.deinit();
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
            const antinodes = try antinode_determination_function(node_pair, width.?, height.?, allocator);
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

    // SERIOUS debugging here - visualizing the output!
    // var lines = std.ArrayList([]u8).init(allocator);
    // defer lines.deinit();
    // for (0..height.?) |_| {
    //     var line = std.ArrayList(u8).init(allocator);
    //     defer line.deinit();
    //     for (0..width.?) |_| {
    //         try line.append('.');
    //     }
    //     try lines.append(line.items);
    // }
    // var lines_items = lines.items;
    // var antinode_iterator_for_visualization = all_antinodes.keyIterator();
    // while (antinode_iterator_for_visualization.next()) |antinode| {
    //     lines_items[antinode.y][antinode.x] = '#';
    // }
    // print("DEBUG - grid is\n", .{});
    // for (lines.items) |line| {
    //     for (line) |c| {
    //         print("{c}", .{c});
    //     }
    //     print("\n", .{});
    // }
    // End of debugging visualization
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

fn findAntinodes(nodes: [2]Point, width: u16, height: u16, allocator: std.mem.Allocator) ![]Point {
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

fn antiNodeIsValid(antiNode: Point, width: u16, height: u16) bool {
    // Don't technically need to check for >= 0 because that's already checked in `findAntinodes` (because otherwise
    // there would be integer overflow by daring to use a negative number :P ), but doesn't hurt to replicate it here -
    // otherwise a future reader might think we've forgotten it.
    return antiNode.x >= 0 and antiNode.y >= 0 and antiNode.x < width and antiNode.y < height;
}

fn part_two(is_test_case: bool) !usize {
    return execute(is_test_case, findAntiNodesHarmonic);
}

fn findAntiNodesHarmonic(nodes: [2]Point, width: usize, height: usize, allocator: std.mem.Allocator) ![]Point {
    print("DEBUG - checking antiNodesHarmonic for {} and {}\n", .{ nodes[0], nodes[1] });

    // Approach:
    // * Find the vector V from nodes[0] to nodes[1]
    // * Find greatest-common-factor of V.x and V.y
    // * Use that to find the smallest integer-step <V'.x, V'.y>
    // * Iteratively (starting from n=0), check nodes[0] + n*V' for legality - then same for subtraction
    //
    // Not making a type for `Vector` because idk how to have a signed size, but it'd be a reasonable approach!
    const vector_x: i32 = @as(i32, nodes[1].x) - @as(i32, nodes[0].x);
    const vector_y: i32 = @as(i32, nodes[1].y) - @as(i32, nodes[0].y);
    const greatest_common_factor = gcf(magnitude(vector_x), magnitude(vector_y));
    const mini_vector_x = divide(vector_x, greatest_common_factor);
    const mini_vector_y = divide(vector_y, greatest_common_factor);
    print("DEBUG - vector_x is {}, mini_vector_x is {}, vector_y is {}, mini_vector_y is {}, gcd is {}\n", .{ vector_x, mini_vector_x, vector_y, mini_vector_y, greatest_common_factor });

    var candidates = std.ArrayList(Point).init(allocator);
    defer candidates.deinit();
    var step: i32 = 0;
    while (true) : (step += 1) {
        var skips: usize = 0;
        const x_step: i32 = step * mini_vector_x;
        const y_step: i32 = step * mini_vector_y;
        print("DEBUG - step is {}, x_step is {}, y_step is {}\n", .{ step, x_step, y_step });

        if (nodes[0].x < x_step or nodes[0].y < y_step or (x_step < 0 and (magnitude(x_step) + nodes[0].x >= width)) or (y_step < 0 and (magnitude(y_step) + nodes[0].y >= height))) {
            skips += 1;
        } else {
            const candidate_x: u16 = @intCast(nodes[0].x - x_step);
            const candidate_y: u16 = @intCast(nodes[0].y - y_step);
            try candidates.append(Point{ .x = candidate_x, .y = candidate_y });
        }

        if (nodes[0].x + x_step >= width or nodes[0].y + y_step >= height or (x_step < 0 and magnitude(x_step) > nodes[0].x) or (y_step < 0 and magnitude(y_step) > nodes[0].y)) {
            skips += 1;
        } else {
            const candidate_x: u16 = @intCast(nodes[0].x + x_step);
            const candidate_y: u16 = @intCast(nodes[0].y + y_step);
            try candidates.append(Point{ .x = candidate_x, .y = candidate_y });
        }

        if (skips == 2) {
            break;
        }
    }
    const response = candidates.toOwnedSlice();
    print("Response is {any}\n", .{response});
    return response;
}

// There _must_ be something like this in the standard library, but I couldn't find it at a glance.
fn magnitude(num: i32) u32 {
    if (num < 0) {
        return @intCast(-num);
    } else {
        return @intCast(num);
    }
}

fn gcf(larger: u32, smaller: u32) u32 {
    print("DEBUG - calculating gcf for {} and {}\n", .{ larger, smaller });
    var a = larger;
    const b = smaller;
    if (b > a) {
        print("DEBUG - reversing them\n", .{});
        return gcf(b, a);
    }
    while (a > b) {
        print("DEBUG - subtracting {} from {} ", .{ b, a }); // Note no line-break!
        a -= b;
        print("to get {}\n", .{a});
    }
    if (a == b) {
        print("DEBUG - a == b, returning the value ({})\n", .{a});
        return a;
    } else {
        // a!>b and a!=b => a < b
        print("DEBUG - b is now larger than a ({}, {}), so starting again\n", .{ b, a });
        return gcf(b, a);
    }
}

// Again - this _must_ exist somewhere in the standard library, can't believe I'm missing it
fn divide(num: i32, denom: u32) i32 {
    const denom_as_i32: i32 = @intCast(denom);
    const divided_value: i32 = @divExact(num, denom_as_i32);
    return divided_value;
}

const expect = std.testing.expect;

test "part_one" {
    const part_one_response = try part_one(true);
    print("DEBUG - part_one_response is {}\n", .{part_one_response});
    try expect(part_one_response == 14);
}

test "greatest_common_factor" {
    try expect(gcf(18, 27) == 9);
    try expect(gcf(182664, 154875) == 177);
}

test "magnitude" { // Pop pop!
    try expect(magnitude(5) == 5);
    try expect(magnitude(-32) == 32);
}

test "divide" {
    try expect(divide(4, 2) == 2);
    try expect(divide(-4, 2) == -2);
    try expect(divide(25, 5) == 5);
    try expect(divide(-50, 2) == -25);
}

test "part_two" {
    const part_two_response = try part_two(true);
    print("DEBUG - part_two_response is {}\n", .{part_two_response});
    try expect(part_two_response == 34);
}
