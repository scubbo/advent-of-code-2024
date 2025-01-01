const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");

pub fn main() !void {
    const response = try part_one(false);
    print("{}\n", .{response});
}

const Location = struct {
    x: usize,
    y: usize,
    // The amount of casting in this is astonishing. Surely there must be a better way to do this?
    fn newLocation(start: Location, x_move: i32, y_move: i32, width: usize, height: usize) ?Location {
        const start_x_as_i32: i32 = @intCast(start.x);
        const new_x = start_x_as_i32 + x_move;
        const start_y_as_i32: i32 = @intCast(start.y);
        const new_y = start_y_as_i32 + y_move;

        if (new_x < 0 or new_x >= width or new_y < 0 or new_y >= height) {
            return null;
        }
        return Location{ .x = @intCast(new_x), .y = @intCast(new_y) };
    }
};

fn part_one(is_test_case: bool) anyerror!u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("10", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    const grid = try buildGrid(data, allocator);
    defer allocator.free(grid);
    print("{any}\n", .{grid});

    // If we wanted, we could find trailheads during the `buildGrid` iteration, but given the small data sizes I'd much
    // rather keep small focused functions at the cost of some constant-factor performance.
    var total: u32 = 0;
    var i: usize = 0;
    while (i < grid.len) : (i += 1) {
        var j: usize = 0;
        while (j < grid[0].len) : (j += 1) {
            if (grid[i][j] == 0) {
                var so_far = std.AutoHashMap(Location, bool).init(allocator);
                const err = getReachablePeaks(grid, Location{ .x = j, .y = i }, 0, &so_far, allocator);
                if (err != null) {
                    return err.?;
                }
                const score = so_far.count();
                print("DEBUG - for the trailhead at {}/{}, found a trailscore of {}\n", .{ j, i, score });
                total += score;
                so_far.deinit();
            }
        }
    }

    // Wow I do _not_ like memory management
    for (grid) |line| {
        allocator.free(line);
    }

    return total;
}

fn buildGrid(data: []const u8, alloc: std.mem.Allocator) ![][]u32 {
    var lines = std.ArrayList([]u32).init(alloc);
    defer lines.deinit();

    var current_line = std.ArrayList(u32).init(alloc);
    defer current_line.deinit();

    for (data) |c| {
        if (c == '\n') {
            const slice = try current_line.toOwnedSlice();
            try lines.append(slice);
        } else {
            try current_line.append(c - 48);
        }
    }
    return try lines.toOwnedSlice();
}

fn buildNeighbours(grid: [][]u32, location: Location, alloc: std.mem.Allocator) ![]Location {
    var neighbours = std.ArrayList(Location).init(alloc);
    defer neighbours.deinit();

    const up = Location.newLocation(location, 0, -1, grid[0].len, grid.len);
    if (up != null) {
        try neighbours.append(up.?);
    }

    const right = Location.newLocation(location, 1, 0, grid[0].len, grid.len);
    if (right != null) {
        try neighbours.append(right.?);
    }

    const down = Location.newLocation(location, 0, 1, grid[0].len, grid.len);
    if (down != null) {
        try neighbours.append(down.?);
    }

    const left = Location.newLocation(location, -1, 0, grid[0].len, grid.len);
    if (left != null) {
        try neighbours.append(left.?);
    }

    return neighbours.toOwnedSlice();
}

fn getReachablePeaks(grid: [][]u32, start: Location, start_value: u32, so_far: *std.AutoHashMap(Location, bool), alloc: std.mem.Allocator) ?anyerror {
    if (start_value == 9) {
        try so_far.put(start, true);
        return null;
    }

    // Check up, down, left, right - if they have the right next value, iterate from there
    const neighbours = try buildNeighbours(grid, start, alloc);
    for (neighbours) |neighbour| {
        if (grid[neighbour.y][neighbour.x] == start_value + 1) {
            const err = getReachablePeaks(grid, neighbour, start_value + 1, so_far, alloc);
            if (err != null) {
                return err;
            }
        }
    }
    alloc.free(neighbours);
    return null;
}

const expect = std.testing.expect;

test "part_one" {
    const part_one_response = try part_one(true);
    print("DEBUG - part_one_response is {}\n", .{part_one_response});
    try expect(part_one_response == 36);
}
