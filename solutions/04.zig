const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");

pub fn main() !void {
    const output = try part_two();
    print("{}\n", .{output});
}

const Location = struct { x: u32, y: u32 };

const NavigationError = error{OutOfBounds};

const Direction = enum {
    north,
    north_east,
    east,
    south_east,
    south,
    south_west,
    west,
    north_west,

    // Errors if asked to go below zero
    fn progress(self: Direction, from: Location) NavigationError!Location {
        return switch (self) {
            Direction.north => {
                if (from.y > 0) {
                    return Location{ .x = from.x, .y = from.y - 1 };
                } else {
                    return error.OutOfBounds;
                }
            },
            Direction.north_east => {
                if (from.y > 0) {
                    return Location{ .x = from.x + 1, .y = from.y - 1 };
                } else {
                    return error.OutOfBounds;
                }
            },
            Direction.east => Location{ .x = from.x + 1, .y = from.y },
            Direction.south_east => Location{ .x = from.x + 1, .y = from.y + 1 },
            Direction.south => Location{ .x = from.x, .y = from.y + 1 },
            Direction.south_west => {
                if (from.x > 0) {
                    return Location{ .x = from.x - 1, .y = from.y + 1 };
                } else {
                    return error.OutOfBounds;
                }
            },
            Direction.west => {
                if (from.x > 0) {
                    return Location{ .x = from.x - 1, .y = from.y };
                } else {
                    return error.OutOfBounds;
                }
            },
            Direction.north_west => {
                if (from.x > 0 and from.y > 0) {
                    return Location{ .x = from.x - 1, .y = from.y - 1 };
                } else {
                    return error.OutOfBounds;
                }
            },
        };
    }

    pub fn getIndicesFromStartingPoint(self: Direction, starting_point: Location) ![4]Location {
        var response: [4]Location = undefined;
        response[0] = starting_point;
        var idx: u8 = 1;
        while (idx < 4) {
            response[idx] = try self.progress(response[idx - 1]);
            idx += 1;
        }
        return response;
    }
};

// !?
const ALL_DIRECTIONS: [8]Direction = .{ Direction.north, Direction.north_east, Direction.east, Direction.south_east, Direction.south, Direction.south_west, Direction.west, Direction.north_west };

pub fn part_one() !u32 {
    // Logic:
    // * Iterate over the letters
    // * When X is found:
    //   * Iterate over all 8 directions
    //   * If an XMAS is found in that direction, increment counter
    const is_test_case: bool = true;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const data = try util.readAllInput(try util.getInputFile("04", is_test_case));
    // https://stackoverflow.com/a/79199470/1040915
    var it = std.mem.splitScalar(u8, data, '\n');
    var lines_list = std.ArrayList([]const u8).init(allocator);
    defer lines_list.deinit();
    while (it.next()) |line| {
        if (line.len > 1) {
            try lines_list.append(line);
        }
    }
    const lines = lines_list.items;
    // Makes the assumption that all lines are the same length.
    // In real production code, we'd assert that.
    const line_length = lines[0].len;
    const number_of_lines = lines.len;
    print("DEBUG - line_length is {} and number_of_lines is {}\n", .{ line_length, number_of_lines });

    var x: u32 = 0;
    var number_of_xmasses: u32 = 0;
    while (x < line_length) : (x += 1) {
        var y: u32 = 0;
        while (y < number_of_lines) : (y += 1) {
            const starting_point = Location{ .x = x, .y = y };
            print("SUPER-DEBUG - checking in neighbourhood of {}\n", .{starting_point});

            // Short-circuit - only do checking if the starting_point is `X`
            if (lines[starting_point.y][starting_point.x] != 'X') {
                continue;
            }
            print("DEBUG - found an X at {}\n", .{starting_point});
            for (ALL_DIRECTIONS) |dir| {
                if (is_valid_xmas(lines, starting_point, dir)) {
                    number_of_xmasses += 1;
                }
            }
        }
    }
    return number_of_xmasses;
}

fn is_valid_xmas(data: [][]const u8, starting_point: Location, dir: Direction) bool {
    const indices = dir.getIndicesFromStartingPoint(starting_point) catch {
        // If we fail to get the indices (because they strayed out-of-bounds), then of _course_ that's not a valid XMAS.
        return false;
    };
    // Check for validity to avoid bounds issues
    for (indices) |index| {
        if (index.x >= data[0].len or index.y >= data.len) {
            return false;
        }
    }
    print("DEBUG - checking indices {any}\n", .{indices});
    const return_value = (data[indices[0].y][indices[0].x] == 'X' and
        data[indices[1].y][indices[1].x] == 'M' and
        data[indices[2].y][indices[2].x] == 'A' and
        data[indices[3].y][indices[3].x] == 'S');
    if (return_value) {
        print("DEBUG - found an XMAS at {}, going {}\n", .{ starting_point, dir });
    }
    return return_value;
}

const expect = std.testing.expect;

test "part_one" {
    try expect(try part_one() == 18);
}

// ==========
pub fn part_two() !u32 {
    // Logic:
    // * Iterate over the letters
    // * When M is found:
    //   * Look for a X going forwards-down and backwards-down
    // (No need to look for Xs going upwards because all upward-crosses will have already been found as part of an
    // earlier pass)
    const is_test_case: bool = true;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const data = try util.readAllInput(try util.getInputFile("04", is_test_case));
    // https://stackoverflow.com/a/79199470/1040915
    var it = std.mem.splitScalar(u8, data, '\n');
    var lines_list = std.ArrayList([]const u8).init(allocator);
    defer lines_list.deinit();
    while (it.next()) |line| {
        if (line.len > 1) {
            try lines_list.append(line);
        }
    }
    const lines = lines_list.items;
    // Makes the assumption that all lines are the same length.
    // In real production code, we'd assert that.
    const line_length = lines[0].len;
    const number_of_lines = lines.len;
    print("DEBUG - line_length is {} and number_of_lines is {}\n", .{ line_length, number_of_lines });

    var x: u32 = 0;
    var number_of_xmasses: u32 = 0;
    while (x < line_length) : (x += 1) {
        var y: u32 = 0;
        while (y < number_of_lines) : (y += 1) {
            const starting_point = Location{ .x = x, .y = y };
            print("SUPER-DEBUG - checking in neighbourhood of {}\n", .{starting_point});

            // Short-circuit - only do checking if the starting_point is `M`
            if (lines[starting_point.y][starting_point.x] != 'M') {
                continue;
            }
            print("DEBUG - found a M at {}\n", .{starting_point});

            // I could probably have implemented `is_valid_cross` as a single function taking a 4-value enum, but, ehh.
            for ([2]bool{ true, false }) |is_forwards| {
                if (is_valid_horizontal_cross(lines, starting_point, is_forwards)) {
                    number_of_xmasses += 1;
                }
            }
            for ([2]bool{ true, false }) |is_upward| {
                if (is_valid_vertical_cross(lines, starting_point, is_upward)) {
                    number_of_xmasses += 1;
                }
            }
        }
    }
    return number_of_xmasses;
}

fn is_valid_horizontal_cross(data: [][]const u8, starting_point: Location, is_forward: bool) bool {
    if (is_forward) {
        if (starting_point.x >= data[0].len - 2 or starting_point.y >= data.len - 2) {
            return false;
        }

        const found_forward_cross = (data[starting_point.y + 2][starting_point.x] == 'M' and
            data[starting_point.y + 1][starting_point.x + 1] == 'A' and
            data[starting_point.y][starting_point.x + 2] == 'S' and
            data[starting_point.y + 2][starting_point.x + 2] == 'S');
        if (found_forward_cross) {
            print("Found forward cross\n", .{});
        }
        return found_forward_cross;
    } else {
        if (starting_point.x < 2 or starting_point.y >= data.len - 2) {
            return false;
        }
        const found_backward_cross = (data[starting_point.y + 2][starting_point.x] == 'M' and
            data[starting_point.y + 1][starting_point.x - 1] == 'A' and
            data[starting_point.y][starting_point.x - 2] == 'S' and
            data[starting_point.y + 2][starting_point.x - 2] == 'S');
        if (found_backward_cross) {
            print("Found backward cross\n", .{});
        }
        return found_backward_cross;
    }
}

fn is_valid_vertical_cross(data: [][]const u8, starting_point: Location, is_upward: bool) bool {
    if (is_upward) {
        if (starting_point.y < 2 or starting_point.x >= data[0].len - 2) {
            return false;
        }

        const found_upward_cross = (data[starting_point.y][starting_point.x + 2] == 'M' and
            data[starting_point.y - 1][starting_point.x + 1] == 'A' and
            data[starting_point.y - 2][starting_point.x] == 'S' and
            data[starting_point.y - 2][starting_point.x + 2] == 'S');
        if (found_upward_cross) {
            print("Found upward cross\n", .{});
        }
        return found_upward_cross;
    } else {
        if (starting_point.y >= data.len - 2 or starting_point.x >= data[0].len - 2) {
            return false;
        }
        const found_downward_cross = (data[starting_point.y][starting_point.x + 2] == 'M' and
            data[starting_point.y + 1][starting_point.x + 1] == 'A' and
            data[starting_point.y + 2][starting_point.x] == 'S' and
            data[starting_point.y + 2][starting_point.x + 2] == 'S');
        if (found_downward_cross) {
            print("Found downward cross\n", .{});
        }
        return found_downward_cross;
    }
}

test "part_two" {
    const answer_of_part_two = try part_two();
    print("DEBUG - answer is {}\n", .{answer_of_part_two});
    try expect(answer_of_part_two == 9);
}
