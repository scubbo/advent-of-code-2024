const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");

pub fn main() !void {
    const response = try part_one(false);
    print("{}\n", .{response});
}

fn part_one(is_test_case: bool) anyerror!u128 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("12", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    var it = std.mem.splitScalar(u8, data, '\n');
    var lines_list = std.ArrayList([]u8).init(allocator);

    while (it.next()) |n| {
        var inner_line_list = std.ArrayList(u8).init(allocator);
        for (n) |c| {
            try inner_line_list.append(c);
        }
        try lines_list.append(try inner_line_list.toOwnedSlice());
    }
    const lines = try lines_list.toOwnedSlice();
    defer allocator.free(lines);
    defer {
        for (lines) |line| {
            allocator.free(line);
        }
    }

    const height = lines.len;
    const width = lines[0].len;

    var total: u128 = 0;
    var i: usize = 0;
    while (i < height) : (i += 1) {
        var j: usize = 0;
        while (j < width) : (j += 1) {
            total += startExploringFrom(i, j, lines);
        }
    }
    return total;
}

fn startExploringFrom(i: usize, j: usize, lines: [][]u8) u128 {
    print("Starting exploring from {}/{}\n", .{ i, j });
    const value = lines[i][j];
    if (value == '.' or value > 90) { // i.e. if letter is lowercase
        return 0;
    }
    const response = exploreFrom(
        i,
        j,
        lines,
        value,
    );
    print("Calculated area {} and perimeter {} for region of value {c} starting at {}/{}\n", .{ response.area, response.perimeter, value, i, j });
    return response.area * response.perimeter;
}

fn exploreFrom(i: usize, j: usize, lines: [][]u8, original_value: u8) struct { area: u128, perimeter: u128 } {
    print("Exploring from {}/{}\n", .{ i, j });
    var area: u128 = 0;
    var perimeter: u128 = 0;

    // To avoid double-counting - mark as '.' initially, then as the lower-case version of the letter when the
    // flood-fill is completed (else we'll find false internal perimeters by detecting '.' as "different")
    lines[i][j] = '.';

    if (i >= 1 and neighbourMatches(i - 1, j, lines, original_value) and lines[i - 1][j] != '.' and lines[i - 1][j] != original_value + 32) {
        const response = exploreFrom(i - 1, j, lines, original_value);
        area += response.area;
        perimeter += response.perimeter;
    } else {
        if ((i >= 1 and lines[i - 1][j] != '.' and lines[i - 1][j] != original_value + 32) or i == 0) {
            perimeter += 1;
            print("DEBUG - adding 1 to perimeter for up of {}/{}\n", .{ i, j });
        } else {
            print("DEBUG - up from {}/{} is an internal boundary, not a perimeter\n", .{ i, j });
        }
    }
    if (j >= 1 and neighbourMatches(i, j - 1, lines, original_value) and lines[i][j - 1] != '.' and lines[i][j - 1] != original_value + 32) {
        const response = exploreFrom(i, j - 1, lines, original_value);
        area += response.area;
        perimeter += response.perimeter;
    } else {
        if ((j >= 1 and lines[i][j - 1] != '.' and lines[i][j - 1] != original_value + 32) or j == 0) {
            perimeter += 1;
            print("DEBUG - adding 1 to perimeter for left of {}/{}\n", .{ i, j });
        } else {
            print("DEBUG - left from {}/{} is an internal boundary, not a perimeter\n", .{ i, j });
        }
    }
    if (neighbourMatches(i + 1, j, lines, original_value) and lines[i + 1][j] != '.' and lines[i + 1][j] != original_value + 32) {
        const response = exploreFrom(i + 1, j, lines, original_value);
        area += response.area;
        perimeter += response.perimeter;
    } else {
        if ((i < lines.len - 1 and lines[i + 1][j] != '.' and lines[i + 1][j] != original_value + 32) or i == lines.len - 1) {
            perimeter += 1;
            print("DEBUG - adding 1 to perimeter for down of {}/{}\n", .{ i, j });
        } else {
            print("DEBUG - down from {}/{} is an internal boundary, not a perimeter\n", .{ i, j });
        }
    }
    if (neighbourMatches(i, j + 1, lines, original_value) and lines[i][j + 1] != '.' and lines[i][j + 1] != original_value + 32) {
        const response = exploreFrom(i, j + 1, lines, original_value);
        area += response.area;
        perimeter += response.perimeter;
    } else {
        if ((j < lines[0].len - 1 and lines[i][j + 1] != '.' and lines[i][j + 1] != original_value + 32) or j == lines[0].len - 1) {
            perimeter += 1;
            print("DEBUG - adding 1 to perimeter for right of {}/{}\n", .{ i, j });
        } else {
            print("DEBUG - right from {}/{} is an internal boundary, not a perimeter\n", .{ i, j });
        }
    }

    lines[i][j] = original_value + 32;

    return .{ .area = area + 1, .perimeter = perimeter };
}

fn neighbourMatches(i: usize, j: usize, lines: [][]u8, original_value: u8) bool {
    if (i < 0 or j < 0 or i >= lines.len or j >= lines[0].len) {
        return false;
    } else {
        return lines[i][j] == original_value;
    }
}

const expect = std.testing.expect;

test "part_one" {
    const part_one_response = try part_one(true);
    print("DEBUG - part_one_response is {}\n", .{part_one_response});
    try expect(part_one_response == 1930);
}
