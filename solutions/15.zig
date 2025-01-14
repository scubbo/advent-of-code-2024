const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");
const expect = std.testing.expect;

// OMG come on part two does not seem fun at all.

pub fn main() !void {
    const response = try part_one(false);
    print("{}\n", .{response});
}

const Point = struct {
    x: usize,
    y: usize,

    pub fn left(self: Point) Point {
        return Point{ .x = self.x - 1, .y = self.y };
    }

    pub fn up(self: Point) Point {
        return Point{ .x = self.x, .y = self.y - 1 };
    }

    pub fn right(self: Point) Point {
        return Point{ .x = self.x + 1, .y = self.y };
    }

    pub fn down(self: Point) Point {
        return Point{ .x = self.x, .y = self.y + 1 };
    }
};

fn part_one(is_test_case: bool) anyerror!u32 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("15", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    var map_list = std.ArrayList([]u8).init(allocator);

    var it = std.mem.splitScalar(u8, data, '\n');
    var robot_position: Point = undefined;
    var line_counter: usize = 0;
    while (it.next()) |line| : (line_counter += 1) {
        if (std.mem.eql(u8, line, "")) {
            break;
        }
        // There _must_ be a better way of doing this - why can't we just copy the data in as a slice rather than having
        // to copy character-by-character?
        // (I know that "under-the-hood" those are the same operations, but it should be easier for a developer to
        // write)
        var line_list = std.ArrayList(u8).init(allocator);
        for (line) |c| {
            try line_list.append(c);
        }
        try map_list.append(try line_list.toOwnedSlice());

        const index_of_at = std.mem.indexOf(u8, line, "@");
        if (index_of_at != null) {
            print("DEBUG - found the robot at {}/{}\n", .{ index_of_at.?, line_counter });
            robot_position = Point{ .x = index_of_at.?, .y = line_counter };
        }
    }
    const map = try map_list.toOwnedSlice();
    defer allocator.free(map);
    defer {
        for (map) |line| {
            allocator.free(line);
        }
    }
    print("DEBUG - finished setting up the map, now reading and executing move instructions\n", .{});

    // The rest of `it` are lines of instructions
    while (it.next()) |instructions_line| {
        print("DEBUG - instructions line is {s}\n", .{instructions_line});
        for (instructions_line) |direction| {
            robot_position = try move(map, robot_position, direction, allocator);
        }
    }

    return calculate_score(map);
}

const MoveError = error{ RobotMislocated, UnexpectedDirection, UnexpectedValue };

// Returns the new position that the robot is at
fn move(map: [][]u8, robot_position: Point, direction: u8, allocator: std.mem.Allocator) anyerror!Point {
    if (map[robot_position.y][robot_position.x] != '@') {
        // Could give some more debugging info - but, string-construction in Zig is such a pain, I'll add that if and
        // when it's needed
        print("DEBUG - something has gone wrong - the robot is not at the expected position\n", .{});
        return MoveError.RobotMislocated;
    }
    print("DEBUG - trying to move the robot (at position {}/{}) in direction {c}\n", .{ robot_position.x, robot_position.y, direction });
    const move_direction_function = switch (direction) {
        '^' => &Point.up,
        '>' => &Point.right,
        'v' => &Point.down,
        '<' => &Point.left,
        else => {
            print("Encountered an unexpected direction: {c}\n", .{direction});
            return MoveError.UnexpectedDirection;
        },
    };
    const response = try try_move(map, robot_position, move_direction_function, allocator);
    defer allocator.free(response);
    if (response.len == 0) {
        // I.e. could not push boxes because they form a line into a wall
        // debugPrintTheMap(map);
        return robot_position;
    }

    for (response) |box_filled_point| {
        map[box_filled_point.y][box_filled_point.x] = 'O';
    }
    map[robot_position.y][robot_position.x] = '.';
    const new_robot_position = move_direction_function(robot_position);
    map[new_robot_position.y][new_robot_position.x] = '@';

    // debugPrintTheMap(map);

    return new_robot_position;
}

fn debugPrintTheMap(map: [][]u8) void {
    print("DEBUG - printing the map\n\n", .{});
    for (map) |line| {
        for (line) |c| {
            print("{c} ", .{c});
        }
        print("\n", .{});
    }
}

// Attempt a move using the move_direction_function given.
// If successful, return a slice of the points that should be updated to hold boxes.
// If unsuccessful (i.e. if the boxes form a line into a wall), return an empty slice
//
// (Note that this actually leads to some weird intermediate situations, in that the space that the robot is about to
// move into will _still_ have a box in (or, in the case where the robot's not pushing a box, will have a box created
// in it) - but that will then get overriden by the robot itself, anyway, leading to a correct eventual outcome)
fn try_move(map: [][]u8, robot_position: Point, move_direction_function: *const fn (self: Point) Point, allocator: std.mem.Allocator) error{ RobotMislocated, UnexpectedValue, OutOfMemory }![]Point {
    var ret = std.ArrayList(Point).init(allocator);
    var variable_robot_position = robot_position;
    while (true) {
        variable_robot_position = move_direction_function(variable_robot_position);
        switch (map[variable_robot_position.y][variable_robot_position.x]) {
            'O' => {
                try ret.append(variable_robot_position);
            },
            '.' => {
                try ret.append(variable_robot_position);
                return ret.toOwnedSlice();
            },
            '#' => {
                ret.deinit();
                return allocator.alloc(Point, 0);
            },
            else => {
                ret.deinit();
                print("Found unexpected value {c} at {}/{}\n", .{ map[variable_robot_position.y][variable_robot_position.x], variable_robot_position.y, variable_robot_position.x });
                return MoveError.UnexpectedValue;
            },
        }
    }
}

fn calculate_score(map: [][]u8) u32 {
    var return_value: u32 = 0;
    for (map, 0..) |line, i| {
        for (line, 0..) |c, j| {
            if (c == 'O') {
                const increment: u32 = @intCast((100 * i) + j);
                print("DEBUG - found a box at {}/{}, so adding {} to the score\n", .{ i, j, increment });
                return_value += increment;
            }
        }
    }
    return return_value;
}

test "part_one" {
    const part_one_response = try part_one(true);
    print("DEBUG - part_one_response is {}\n", .{part_one_response});
    try expect(part_one_response == 2028);
}
