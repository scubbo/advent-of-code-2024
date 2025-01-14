const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");
const expect = std.testing.expect;

pub fn main() !void {
    // const response = try part_one(false);
    // print("{}\n", .{response});
    try part_two();
}

const Point = struct { x: u32, y: u32 };

const Velocity = struct { x: i32, y: i32 };

const Robot = struct {
    position: Point,
    velocity: Velocity,

    pub fn move(self: *Robot, width: usize, height: usize) void {
        // I wish it were possible to put this on multiple lines, but it appears to be a syntax error
        const new_x: u32 = @intCast(if (self.velocity.x >= 0) (self.position.x + util.magnitude(self.velocity.x)) % width else (self.position.x + (width - util.magnitude(self.velocity.x))) % width);

        const new_y: u32 = @intCast(if (self.velocity.y >= 0) (self.position.y + util.magnitude(self.velocity.y)) % height else (self.position.y + (height - util.magnitude(self.velocity.y))) % height);

        self.position = Point{ .x = new_x, .y = new_y };
    }

    pub fn move_iterated(self: *Robot, width: usize, height: usize, move_count: u32) void {
        for (0..move_count) |_| {
            // Technically inefficient in that it does the modulo operation on every movement, but the alternative would
            // be having to deal with Zig's bullshit integer limits, so... :shrug:
            self.move(width, height);
        }
    }

    pub fn from_line(line: []const u8) !Robot {
        // print("DEBUG - parsing line {s}\n", .{line});
        const start_pos_x: usize = 2;
        const end_pos_x: usize = std.mem.indexOf(u8, line, ",").?;
        // print("DEBUG - end_pos_x is {}\n", .{end_pos_x});
        const start_pos_y: usize = end_pos_x + 1;
        const end_pos_y: usize = std.mem.indexOf(u8, line, " ").?;
        // print("DEBUG - end_pos_y is {}\n", .{end_pos_y});

        const start_vel_x: usize = std.mem.indexOf(u8, line, "v").? + 2;
        // print("DEBUG - start_vel_x is {}\n", .{start_vel_x});
        const end_vel_x: usize = std.mem.indexOf(u8, line[end_pos_y..], ",").? + end_pos_y;
        // print("DEBUG - end_vel_x is {}\n", .{end_vel_x});
        const start_vel_y: usize = end_vel_x + 1;
        const end_vel_y: usize = line.len;

        const x = try std.fmt.parseInt(u32, line[start_pos_x..end_pos_x], 10);
        const y = try std.fmt.parseInt(u32, line[start_pos_y..end_pos_y], 10);
        const vel_x = try std.fmt.parseInt(i32, line[start_vel_x..end_vel_x], 10);
        const vel_y = try std.fmt.parseInt(i32, line[start_vel_y..end_vel_y], 10);

        print("DEBUG - x, y, vel_x, vel_y are {}, {}, {}, {}\n", .{ x, y, vel_x, vel_y });

        return Robot{ .position = Point{ .x = x, .y = y }, .velocity = Velocity{ .x = vel_x, .y = vel_y } };
    }
};

fn part_one(is_test_case: bool) anyerror!u32 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("14", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    var it = std.mem.splitScalar(u8, data, '\n');
    var robots = std.ArrayList(Robot).init(allocator);
    defer robots.deinit();

    const height: u32 = if (is_test_case) 7 else 103;
    const width: u32 = if (is_test_case) 11 else 101;

    while (it.next()) |line| {
        try robots.append(try Robot.from_line(line));
    }

    var first_quadrant_count: u32 = 0;
    var second_quadrant_count: u32 = 0;
    var third_quadrant_count: u32 = 0;
    var fourth_quadrant_count: u32 = 0;
    // I don't know why this has to be `*robot` - see question [here](https://ziggit.dev/t/how-to-get-a-non-const-pointer-to-a-structs-field-from-within-a-function-of-the-struct/7639/13?u=scubbo)
    for (robots.items) |*robot| {
        robot.move_iterated(width, height, 100);
        print("DEBUG - robot in position {}/{}\n", .{ robot.position.x, robot.position.y });
        // Can't use a `switch`, here, as `width/2` and `height/2` are not comptime expressions
        if (robot.position.x < width / 2 and robot.position.y < height / 2) {
            first_quadrant_count += 1;
        }
        if (robot.position.x > width / 2 and robot.position.y < height / 2) {
            second_quadrant_count += 1;
        }
        if (robot.position.x < width / 2 and robot.position.y > height / 2) {
            third_quadrant_count += 1;
        }
        if (robot.position.x > width / 2 and robot.position.y > height / 2) {
            fourth_quadrant_count += 1;
        }
    }
    print("DEBUG - quadrant counts are {}, {}, {}, {}\n", .{ first_quadrant_count, second_quadrant_count, third_quadrant_count, fourth_quadrant_count });
    return first_quadrant_count * second_quadrant_count * third_quadrant_count * fourth_quadrant_count;
}

// ...wtf!? How on earth are you meant to do this without visual inspection?
// ...ok, giving up on this. I stepped through the output (run `zig run solutions 14.zig > /tmp/output 2>&1`, then open in vim and do:
// `qt/Iteration<enter>ztqq` (to record a macro on key `t` which will bring the next iteration to the top of the screen), then repeatedly do
// `@t`) but can't see anything resembling a christmas tree.
// Iterations 12 and 35 both show some structure, but nothing like a tree (and those are both rejected as answers)
fn part_two() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("14", false);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    var it = std.mem.splitScalar(u8, data, '\n');
    var robots = std.ArrayList(Robot).init(allocator);
    defer robots.deinit();

    const height: u32 = if (false) 7 else 103;
    const width: u32 = if (false) 11 else 101;

    while (it.next()) |line| {
        try robots.append(try Robot.from_line(line));
    }
    for (0..100) |iteration| {
        for (robots.items) |*robot| {
            robot.move(width, height);
        }

        var lines = std.ArrayList([]u32).init(allocator);
        for (0..height) |_| {
            var line = std.ArrayList(u32).init(allocator);
            for (0..width) |_| {
                try line.append(0);
            }
            try lines.append(try line.toOwnedSlice());
        }
        const lines_owned = try lines.toOwnedSlice();

        for (robots.items) |*robot| {
            lines_owned[robot.position.y][robot.position.x] += 1;
        }

        // Print out display
        print("Iteration count: {}\n", .{iteration + 1});
        for (lines_owned) |line| {
            for (line) |val| {
                if (val > 0) {
                    print("X", .{});
                } else {
                    print(" ", .{});
                }
            }
            print("|\n", .{}); // I'm cheating by putting this trailing pipe to stop Vim from giving ugly red highlights on trailing whitespace
        }
        print("\n\n", .{});

        for (lines_owned) |line| {
            allocator.free(line);
        }
        allocator.free(lines_owned);
        std.time.sleep(1000000);
    }
}

test "robot movement" {
    var robot = Robot{ .position = Point{ .x = 2, .y = 4 }, .velocity = Velocity{ .x = 2, .y = -3 } };
    robot.move(11, 7);
    print("DEBUG - robot position after one iteration is {}/{}\n", .{ robot.position.x, robot.position.y });
    try expect(robot.position.x == 4);
    try expect(robot.position.y == 1);

    robot.move(11, 7);
    print("DEBUG - robot position after two iterations is {}/{}\n", .{ robot.position.x, robot.position.y });
    try expect(robot.position.x == 6);
    try expect(robot.position.y == 5);

    robot.move(11, 7);
    print("DEBUG - robot position after three iterations is {}/{}\n", .{ robot.position.x, robot.position.y });
    try expect(robot.position.x == 8);
    try expect(robot.position.y == 2);

    robot.move(11, 7);
    print("DEBUG - robot position after four iterations is {}/{}\n", .{ robot.position.x, robot.position.y });
    try expect(robot.position.x == 10);
    try expect(robot.position.y == 6);

    robot.move(11, 7);
    print("DEBUG - robot position after five iterations is {}/{}\n", .{ robot.position.x, robot.position.y });
    try expect(robot.position.x == 1);
    try expect(robot.position.y == 3);
}

test "iterated movement" {
    var robot = Robot{ .position = Point{ .x = 2, .y = 4 }, .velocity = Velocity{ .x = 2, .y = -3 } };
    robot.move_iterated(11, 7, 3);
    print("DEBUG - robot position after three iterations (in one go) is {}/{}\n", .{ robot.position.x, robot.position.y });
    try expect(robot.position.x == 8);
    try expect(robot.position.y == 2);
}

test "part_one" {
    const part_one_response = try part_one(true);
    print("DEBUG - part_one_response is {}\n", .{part_one_response});
    try expect(part_one_response == 12);
}
