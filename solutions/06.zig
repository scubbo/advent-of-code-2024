const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");

const Heading = enum {
    north,
    east,
    south,
    west,
    fn rotate(self: Heading) Heading {
        return switch (self) {
            Heading.north => Heading.east,
            Heading.east => Heading.south,
            Heading.south => Heading.west,
            Heading.west => Heading.north,
        };
    }
};

const Location = struct { x: usize, y: usize };

pub fn main() !void {
    const response = try part_one(false);
    print("{}\n", .{response});
}

pub fn part_one(is_test_case: bool) !u32 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("06", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);

    // https://stackoverflow.com/a/79199470/1040915
    var it = std.mem.splitScalar(u8, data, '\n');
    var lines_list = std.ArrayList([]u8).init(allocator);
    defer lines_list.deinit();

    while (it.next()) |line| {
        if (line.len > 1) {
            var mut_copy = try allocator.alloc(u8, line.len);
            // The line above is leaking memory all over the place, but what's a boy to do?
            // The only solution I know (`defer allocator.free(mut_copy);`) leads to segmentation faults
            // Related to (though not the same as) my question here: https://stackoverflow.com/questions/79305128/how-to-idiomatically-return-an-accumulated-slice-array-from-a-zig-function
            var idx: usize = 0;
            while (idx < line.len) : (idx += 1) {
                mut_copy[idx] = line[idx];
            }
            try lines_list.append(mut_copy);
        }
    }
    var lines = lines_list.items;

    // Find starting point
    var x: usize = 0;
    var location: Location = undefined;
    while (x < lines[0].len) : (x += 1) {
        var y: usize = 0;
        while (y < lines.len) : (y += 1) {
            if (lines[y][x] == '^') {
                location = Location{ .x = x, .y = y };
                lines[y][x] = '.';
            }
        }
    }
    print("DEBUG - starting location is {}\n", .{location});
    var heading = Heading.north;
    var total_distinct_locations: u32 = 0;
    while (true) {
        const next_square = getNextSquare(location, heading, lines[0].len, lines.len) catch break;
        if (lines[next_square.y][next_square.x] == '#') {
            heading = heading.rotate();
            continue;
        } else {
            if (lines[location.y][location.x] != 'X') {
                lines[location.y][location.x] = 'X';
                total_distinct_locations += 1;
            }
            location = next_square;
        }
    }
    return total_distinct_locations + 1;
}

const NavigationError = error{ OutOfBounds, UnexpectedTriplicateVisit };

fn getNextSquare(current_square: Location, heading: Heading, max_x: usize, max_y: usize) !Location {
    return switch (heading) {
        Heading.north => {
            if (current_square.y == 0) {
                return NavigationError.OutOfBounds;
            } else {
                return Location{ .x = current_square.x, .y = current_square.y - 1 };
            }
        },
        Heading.east => {
            if (current_square.x == max_x - 1) {
                return NavigationError.OutOfBounds;
            } else {
                return Location{ .x = current_square.x + 1, .y = current_square.y };
            }
        },
        Heading.south => {
            if (current_square.y == max_y - 1) {
                return NavigationError.OutOfBounds;
            } else {
                return Location{ .x = current_square.x, .y = current_square.y + 1 };
            }
        },
        Heading.west => {
            if (current_square.x == 0) {
                return NavigationError.OutOfBounds;
            } else {
                return Location{ .x = current_square.x - 1, .y = current_square.y };
            }
        },
    };
}

// Not a working implementation - I'm moving on to other problems rather than continuing to struggle on something that's
// a) not interesting me, and b) not teaching me new techniques.
pub fn part_two(is_test_case: bool) !u32 {
    // Mostly the same logic as part_one to start with, but:
    // * when leaving a square, note the heading it was left with
    // * when visiting a square that has previously been visited, check if it is relatively-right (i.e. if moving north,
    //    check if the square was previously-departed to the east). If so - this is an opportunity to create a loop
    // * make sure to note all these opportunities and dedupe them rather than counting them naively!
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("06", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);

    // https://stackoverflow.com/a/79199470/1040915
    var it = std.mem.splitScalar(u8, data, '\n');
    var lines_list = std.ArrayList([]u8).init(allocator);
    defer lines_list.deinit();

    while (it.next()) |line| {
        if (line.len > 1) {
            var mut_copy = try allocator.alloc(u8, line.len);
            // The line above is leaking memory all over the place, but what's a boy to do?
            // The only solution I know (`defer allocator.free(mut_copy);`) leads to segmentation faults
            // Related to (though not the same as) my question here: https://stackoverflow.com/questions/79305128/how-to-idiomatically-return-an-accumulated-slice-array-from-a-zig-function
            var idx: usize = 0;
            while (idx < line.len) : (idx += 1) {
                mut_copy[idx] = line[idx];
            }
            try lines_list.append(mut_copy);
        }
    }
    var lines = lines_list.items;

    // Find starting point
    var x: usize = 0;
    var location: Location = undefined;
    outer: while (x < lines[0].len) : (x += 1) {
        var y: usize = 0;
        while (y < lines.len) : (y += 1) {
            if (lines[y][x] == '^') {
                location = Location{ .x = x, .y = y };
                lines[y][x] = '.';
                break :outer;
            }
        }
    }
    print("DEBUG - starting location is {}\n", .{location});
    var heading = Heading.north;
    var potential_block_locations = std.ArrayList(Location).init(allocator);
    while (true) {
        const next_square = getNextSquare(location, heading, lines[0].len, lines.len) catch break;
        if (lines[next_square.y][next_square.x] == '#') {
            heading = heading.rotate();
            continue;
        } else {
            // Next square is not an obstacle, so update departed square then move into the target

            // Having just moved into a square - if the just-moved-into-square has already been visited, and was departed
            // relatively-right, then the _next_ square (if it's not an obstacle) is a potential block-location
            if (lines[location.y][location.x] != '.') {
                try potential_block_locations.append(next_square);
                print("DEBUG - adding a potential_block_location - {}\n", .{next_square});
            }

            try updateDepartedSquare(&lines, location.y, location.x, heading);
            location = next_square;
        }
    }
    // TODO - dedupe potential_block_locations and return size
    return @intCast(potential_block_locations.items.len);
}

fn updateDepartedSquare(lines: *[][]u8, y: usize, x: usize, heading: Heading) !void {
    // I'm going to naively implement this on the assumption that there are only two opportunities:
    // * The square has never been visited before (so, update content to `URDL` for headings)
    // * The square has been visited exactly once (so, update content to just `X`)
    // (I.e. I am assuming it's not possible for a square to be visited three times, and equivalently that we don't
    // need to record the specific cases of a 2-visit)
    // I am pretty sure that's true (otherwise we'd be in a loop already), but I guess we'll see from the test-cases :P

    const current_value = lines.*[y][x];
    var new_value: u8 = undefined;
    if (current_value == '.') {
        if (heading == Heading.north) {
            new_value = 'U';
        }
        if (heading == Heading.east) {
            new_value = 'R';
        }
        if (heading == Heading.south) {
            new_value = 'D';
        }
        if (heading == Heading.west) {
            new_value = 'L';
        }
    } else {
        if (current_value == 'U' or current_value == 'R' or current_value == 'D' or current_value == 'L') {
            new_value = 'X';
        } else {
            return NavigationError.UnexpectedTriplicateVisit;
        }
    }
    lines.*[y][x] = new_value;

    // Below is a more elegant implementation, but something's off in the type-system
    // const current_value = lines.*[y][x];
    // const new_value: u8 = switch (current_value) {
    //     '.' => {
    //         switch (heading) {
    //             Heading.north => 'U',
    //             Heading.east => 'R',
    //             Heading.south => 'D',
    //             Heading.west => 'L',
    //         }
    //     },
    //     'U', 'R', 'D', 'L' => 'X',
    //     else => {
    //         return NavigationError.UnexpectedTriplicateVisit;
    //     },
    // };
    // lines[y][x] = new_value;
}

const expect = std.testing.expect;

test "part_one" {
    const part_one_response = try part_one(true);
    print("DEBUG - part_one_response is {}\n", .{part_one_response});
    try expect(part_one_response == 41);
}

test "part_two" {
    // const part_two_response = part_two(true) catch |err| {
    //     print("DEBUG - error from part_two {}\n", .{err});
    //     return;
    // };
    const part_two_response = try part_two(true);
    print("DEBUG - part_two_response is {}\n", .{part_two_response});
    try expect(part_two_response == 6);
}
