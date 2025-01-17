const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");
const expect = std.testing.expect;

pub fn main() !void {
    const response = try part_one(false);
    print("{}\n", .{response});
}

const Point = struct { x: usize, y: usize };
const Heading = enum {
    north,
    east,
    south,
    west,
    pub fn turn_left(self: Heading) Heading {
        const int_val = @intFromEnum(self);
        return @enumFromInt(@as(u4, int_val) + 3 % 4);
    }

    pub fn turn_right(self: Heading) Heading {
        const int_val = @intFromEnum(self);
        return @enumFromInt(@as(u4, int_val) + 1 % 4);
    }
};

const Position = struct { point: Point, heading: Heading };

// Sketch solution for Part Two:
// * Extend data structure to keep track of which leading-in nodes generates the shortest distance to a given node. This
//    should be an ArrayList, because multiple leading-in nodes can lead to the same node with the same minimum distance
//    (if distance_so_far + cost is _equal_)
// * Extend the loop to not just return when the target node is reached, but to keep running until `current_distance`
//    is _greater_ than the found minimum_distance_to_target
// * Once the loop terminates (because current_distance is too large), build paths by iterating back from target_node
//    iteratively to all preceding nodes (branching when there are multiple).
// * Keep track of all those points, then dedupe and count.

fn part_one(is_test_case: bool) !u32 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("16", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    var map_list = std.ArrayList([]u8).init(allocator);

    var it = std.mem.splitScalar(u8, data, '\n');
    var start_position: Position = undefined;
    var target_point: Point = undefined;
    var line_counter: usize = 0;

    while (it.next()) |line| : (line_counter += 1) {
        var line_list = std.ArrayList(u8).init(allocator);
        for (line) |c| {
            try line_list.append(c);
        }
        try map_list.append(try line_list.toOwnedSlice());

        const index_of_s = std.mem.indexOf(u8, line, "S");
        if (index_of_s != null) {
            start_position = Position{ .point = Point{ .x = index_of_s.?, .y = line_counter }, .heading = Heading.east };
        }

        const index_of_e = std.mem.indexOf(u8, line, "E");
        if (index_of_e != null) {
            target_point = Point{ .x = index_of_e.?, .y = line_counter };
        }
    }

    const map = try map_list.toOwnedSlice();
    defer allocator.free(map);
    defer {
        for (map) |line| {
            allocator.free(line);
        }
    }

    var distances = std.AutoHashMap(Position, u32).init(allocator);
    defer distances.deinit();
    var visited_positions = std.AutoHashMap(Position, bool).init(allocator);
    defer visited_positions.deinit();

    try distances.put(start_position, 0);
    var current_position = start_position;
    var current_distance: u32 = 0;
    while (true) {
        // print("DEBUG - current_position is {}/{} ({}), and current_distance is {}\n", .{ current_position.point.x, current_position.point.y, current_position.heading, current_distance });
        if (std.meta.eql(current_position.point, target_point)) {
            return current_distance;
        }
        const moves = try find_valid_moves(map, current_position, allocator);

        for (moves) |move| {
            if (visited_positions.contains(move.position)) {
                continue;
            }

            const distance_from_here = current_distance + move.cost;

            // Below is an attempted implementation using `getOrPut`, which I still _really_ don't understand -
            // it required me to make `distance_from_here` a `var` so that I could do
            // `response.value_ptr = &distance_from_here`, and then was putting huge number values (probably - pointers,
            // not the actual values?) into the map. But if I tried `response.value_ptr = distance_from_here`, that gave
            // a type mismatch.
            // var response = try distances.getOrPut(move.position);
            // if (response.found_existing) {
            //     if (distance_from_here < response.value_ptr.*) {
            //         print("DEBUG - found a new lowest distance for {}/{} ({}) - moving from {} to {}\n", .{ move.position.point.x, move.position.point.y, move.position.heading, response.value_ptr.*, distance_from_here });
            //         response.value_ptr = &distance_from_here;
            //     }
            // } else {
            //     print("DEBUG - found fresh lowest distance for {}/{} ({}) - {}\n", .{ move.position.point.x, move.position.point.y, move.position.heading, distance_from_here });
            //     response.value_ptr = &distance_from_here;
            // }
            if (distances.contains(move.position)) {
                const current_lowest_distance = distances.get(move.position).?;
                if (distance_from_here < current_lowest_distance) {
                    // print("DEBUG - found a new lowest distance for {}/{} ({}) - moving from {} to {}\n", .{ move.position.point.x, move.position.point.y, move.position.heading, current_lowest_distance, distance_from_here });
                    try distances.put(move.position, distance_from_here);
                }
            } else {
                // print("DEBUG - found fresh lowest distance for {}/{} ({}) - {}\n", .{ move.position.point.x, move.position.point.y, move.position.heading, distance_from_here });
                try distances.put(move.position, distance_from_here);
            }
        }
        allocator.free(moves);

        try visited_positions.put(current_position, true);

        // Find the next candidate by iterating over all unvisited nodes with non-infinite distance, and picking the one
        // with lowest distance.
        // There would almost-certainly be a way to optimize this with a min-queue if we cared.
        var next_position: Position = undefined;
        // var lowest_distance_found: u32 = std.math.inf(u32);
        // above gives `error: reached unreachable code`
        var lowest_distance_found: u32 = 999999999;
        var dist_it = distances.iterator();
        while (dist_it.next()) |entry| {
            // print("DEBUG - checking whether {}/{}({}) is valid as next current_position - ", .{ entry.key_ptr.point.x, entry.key_ptr.point.y, entry.key_ptr.heading });
            if (visited_positions.contains(entry.key_ptr.*)) {
                // print("no, because it's been visited already\n", .{});
                continue;
            }
            if (entry.value_ptr.* > lowest_distance_found) {
                // print("no, because its distance ({}) is higher than the lowest found so far ({})\n", .{ entry.value_ptr.*, lowest_distance_found });
                continue;
            }
            // print("it is!\n", .{});
            // print("{}/{}({}) is a valid next-position\n", .{ entry.key_ptr.point.x, entry.key_ptr.point.y, entry.key_ptr.heading });
            next_position = entry.key_ptr.*;
            lowest_distance_found = entry.value_ptr.*;
        }
        current_position = next_position;
        current_distance = lowest_distance_found;
    }
}

const Move = struct { position: Position, cost: u32 };

fn find_valid_moves(map: [][]u8, current_position: Position, allocator: std.mem.Allocator) ![]Move {
    var responses = std.ArrayList(Move).init(allocator);

    // First of three cases - move forward (if that's not a wall)
    var neighbour: Point = undefined;
    switch (current_position.heading) {
        Heading.north => {
            // print("DEBUG - north from {}/{} is ", .{ current_position.point.x, current_position.point.y });
            neighbour = Point{ .x = current_position.point.x, .y = current_position.point.y - 1 };
        },
        Heading.east => {
            // print("DEBUG - east from {}/{} is ", .{ current_position.point.x, current_position.point.y });
            neighbour = Point{ .x = current_position.point.x + 1, .y = current_position.point.y };
        },
        Heading.south => {
            // print("DEBUG - south from {}/{} is ", .{ current_position.point.x, current_position.point.y });
            neighbour = Point{ .x = current_position.point.x, .y = current_position.point.y + 1 };
        },
        Heading.west => {
            // print("DEBUG - west from {}/{} is ", .{ current_position.point.x, current_position.point.y });
            neighbour = Point{ .x = current_position.point.x - 1, .y = current_position.point.y };
        },
    }
    // print("{}/{}\n", .{ neighbour.x, neighbour.y });
    if (map[neighbour.y][neighbour.x] == '.' or map[neighbour.y][neighbour.x] == 'E') {
        try responses.append(Move{ .position = Position{ .point = neighbour, .heading = current_position.heading }, .cost = 1 });
    }

    // Second and third cases - turn left and right
    try responses.append(Move{ .position = Position{ .point = current_position.point, .heading = current_position.heading.turn_left() }, .cost = 1000 });
    try responses.append(Move{ .position = Position{ .point = current_position.point, .heading = current_position.heading.turn_right() }, .cost = 1000 });

    return responses.toOwnedSlice();
}

test "turn left and right" {
    try expect(Heading.north.turn_left() == Heading.west);
    try expect(Heading.north.turn_right() == Heading.east);
    try expect(Heading.north.turn_right().turn_right().turn_right().turn_right() == Heading.north);
    try expect(Heading.north.turn_left().turn_left().turn_left() == Heading.east);
}

test "part_one" {
    const part_one_response = try part_one(true);
    print("DEBUG - part_one_response is {}\n", .{part_one_response});
    try expect(part_one_response == 7036);
}
