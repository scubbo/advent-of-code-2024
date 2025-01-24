const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");
const Point = util.Point;
const log = util.log;
const expect = std.testing.expect;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const response = try partTwo(false, false, allocator);
    print("{}\n", .{response});
}

// Sketch of intended logic:
// * Find shortest non-cheating time start-to-finish
// * Find fastest time (don't need to save path) from start _to_ each location
// * Find faster time (ditto) from end _to_ each location
// * Find all cheats
// * For each cheat:
//   * Time saved is basic time - (time-from-start-to-start-of-cheat - time-from-end-of-cheat-to-end)
fn partOne(is_test_case: bool, debug: bool, allocator: std.mem.Allocator) !u32 {
    const input_file = try util.getInputFile("20", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    var map = buildMap(data, allocator);
    defer allocator.free(map);
    defer {
        for (map) |line| {
            allocator.free(line);
        }
    }

    // Technically slightly inefficient to do it this way, as we could have done it during `buildMap`, but I prefer my
    // functions to do one-and-only-one thing.
    const start_point = findPoint(map, 'S');
    const end_point = findPoint(map, 'E');
    // Cleanup the map so that cheats-to-the-end will still be legal
    map[end_point.y][end_point.x] = '.';
    map[start_point.y][start_point.x] = '.';
    log("Start point is {s} and end point is {s}\n", .{ start_point, end_point }, debug);

    const neighboursFunc = &struct {
        pub fn func(d: *const [][]u8, point: *Point, alloc: std.mem.Allocator) []Point {
            var response = std.ArrayList(Point).init(alloc);
            const ns = point.neighbours(d.*[0].len, d.len, alloc);
            for (ns) |n| {
                if (d.*[n.y][n.x] != '#') {
                    response.append(n) catch unreachable;
                }
            }
            alloc.free(ns);
            return response.toOwnedSlice() catch unreachable;
        }
    }.func;

    var distances_map = util.dijkstra([][]u8, Point, &map, neighboursFunc, start_point, null, debug, allocator);
    defer distances_map.deinit();

    var distances_map_from_end = util.dijkstra([][]u8, Point, &map, neighboursFunc, end_point, null, debug, allocator);
    defer distances_map_from_end.deinit();

    const shortest_non_cheating_path = distances_map.get(end_point).?;
    var cheats = findCheatsWithMaximumLength(map, 2, allocator);
    defer cheats.deinit();

    var scored_cheats = scoreCheatsWithVariableLength(cheats, shortest_non_cheating_path, distances_map, distances_map_from_end, debug, allocator);
    defer scored_cheats.deinit();

    var total: u32 = 0;
    var it = scored_cheats.iterator();
    const target_speedup: u8 = if (is_test_case) 12 else 100;
    log("Here are the scored cheats:\n", .{}, debug);
    while (it.next()) |e| {
        if (e.value_ptr.* >= target_speedup) {
            total += 1;
        }
        if (e.value_ptr.* > 0) {
            log("{}: {}\n", .{ e.key_ptr.*, e.value_ptr.* }, debug);
        }
    }

    return total;
}

const Cheat = struct {
    start: Point,
    end: Point,
    pub fn format(self: Cheat, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("[{s},{s}]", .{ self.start, self.end });
    }
};

fn buildNeighboursFunction(map: *const [][]u8) *const fn (p: *Point, alloc: std.mem.Allocator) []Point {
    return struct {
        pub fn call(p: *Point, alloc: std.mem.Allocator) []Point {
            var responseList = std.ArrayList(Point).init(alloc);
            const neighbours = p.neighbours(map[0].len, map.len, alloc);
            for (neighbours) |n| {
                if (map[n.y][n.x] == '.') {
                    responseList.append(n) catch unreachable;
                }
            }
            alloc.free(neighbours);

            return responseList.toOwnedSlice();
        }
    }.call;
}

fn buildMap(data: []const u8, allocator: std.mem.Allocator) [][]u8 {
    var map_list = std.ArrayList([]u8).init(allocator);
    var data_iterator = std.mem.splitScalar(u8, data, '\n');
    while (data_iterator.next()) |data_line| {
        var line = std.ArrayList(u8).init(allocator);
        for (data_line) |c| {
            line.append(c) catch unreachable;
        }
        map_list.append(line.toOwnedSlice() catch unreachable) catch unreachable;
    }
    return map_list.toOwnedSlice() catch unreachable;
}

fn findPoint(data: [][]u8, char: u8) Point {
    for (data, 0..) |line, y| {
        for (line, 0..) |c, x| {
            if (c == char) {
                return Point{ .x = x, .y = y };
            }
        }
    }
    unreachable;
}

test "partOne" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const response = try partOne(true, true, allocator);
    print("Found {} sufficiently-speedy cheats for partOne\n", .{response});
    try expect(response == 8);
}

fn partTwo(is_test_case: bool, debug: bool, allocator: std.mem.Allocator) !u32 {
    const input_file = try util.getInputFile("20", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    var map = buildMap(data, allocator);
    defer allocator.free(map);
    defer {
        for (map) |line| {
            allocator.free(line);
        }
    }

    // Technically slightly inefficient to do it this way, as we could have done it during `buildMap`, but I prefer my
    // functions to do one-and-only-one thing.
    const start_point = findPoint(map, 'S');
    const end_point = findPoint(map, 'E');
    // Cleanup the map so that cheats-to-the-end will still be legal
    map[end_point.y][end_point.x] = '.';
    map[start_point.y][start_point.x] = '.';
    log("Start point is {s} and end point is {s}\n", .{ start_point, end_point }, debug);

    const neighboursFunc = &struct {
        pub fn func(d: *const [][]u8, point: *Point, alloc: std.mem.Allocator) []Point {
            var response = std.ArrayList(Point).init(alloc);
            const ns = point.neighbours(d.*[0].len, d.len, alloc);
            for (ns) |n| {
                if (d.*[n.y][n.x] != '#') {
                    response.append(n) catch unreachable;
                }
            }
            alloc.free(ns);
            return response.toOwnedSlice() catch unreachable;
        }
    }.func;

    var distances_map = util.dijkstra([][]u8, Point, &map, neighboursFunc, start_point, null, debug, allocator);
    defer distances_map.deinit();

    var distances_map_from_end = util.dijkstra([][]u8, Point, &map, neighboursFunc, end_point, null, debug, allocator);
    defer distances_map_from_end.deinit();

    const shortest_non_cheating_path = distances_map.get(end_point).?;
    var cheats = findCheatsWithMaximumLength(map, 20, allocator);
    defer cheats.deinit();

    var scored_cheats = scoreCheatsWithVariableLength(cheats, shortest_non_cheating_path, distances_map, distances_map_from_end, debug, allocator);
    defer scored_cheats.deinit();

    var total: u32 = 0;
    var it = scored_cheats.iterator();
    const target_speedup: u8 = if (is_test_case) 66 else 100;
    log("Here are the scored cheats:\n", .{}, debug);
    while (it.next()) |e| {
        if (e.value_ptr.* >= target_speedup) {
            total += 1;
        }
        if (e.value_ptr.* > 0) {
            log("{}: {}\n", .{ e.key_ptr.*, e.value_ptr.* }, debug);
        }
    }

    return total;
}

fn findCheatsWithMaximumLength(map: [][]u8, maximum_length: u32, allocator: std.mem.Allocator) std.AutoHashMap(Cheat, u64) {
    var output = std.AutoHashMap(Cheat, u64).init(allocator);
    // Just realized - after running this - that I could probably speed this up by only iterating over the Points that are in the distance maps,
    // since those are the only valid (non-wall) spaces. Eh - still only took a coupla seconds. Could add that optimization if it mattered!
    for (map, 0..) |start_line, start_y| {
        for (start_line, 0..) |start_c, start_x| {
            for (map, 0..) |end_line, end_y| {
                for (end_line, 0..) |end_c, end_x| {
                    if (start_c == '.' and end_c == '.') {
                        const cheat = Cheat{ .start = Point{ .x = start_x, .y = start_y }, .end = Point{ .x = end_x, .y = end_y } };
                        const length_of_cheat = findLengthOfCheat(cheat);
                        if (length_of_cheat <= maximum_length) {
                            output.put(cheat, length_of_cheat) catch unreachable;
                        }
                    }
                }
            }
        }
    }
    return output;
}

fn findLengthOfCheat(cheat: Cheat) u64 {
    return @as(u64, (if (cheat.start.x > cheat.end.x) cheat.start.x - cheat.end.x else cheat.end.x - cheat.start.x) + (if (cheat.start.y > cheat.end.y) cheat.start.y - cheat.end.y else cheat.end.y - cheat.start.y));
}

fn scoreCheatsWithVariableLength(cheats: std.AutoHashMap(Cheat, u64), shortest_non_cheating_path: u32, distances_map: std.AutoHashMap(Point, u32), distances_map_from_end: std.AutoHashMap(Point, u32), debug: bool, allocator: std.mem.Allocator) std.AutoHashMap(Cheat, i128) {
    var output = std.AutoHashMap(Cheat, i128).init(allocator);
    var e_it = cheats.iterator();
    while (e_it.next()) |e| {
        output.put(e.key_ptr.*, scoreCheatWithVariableLength(e.key_ptr.*, e.value_ptr.*, shortest_non_cheating_path, distances_map, distances_map_from_end, debug)) catch unreachable;
    }
    return output;
}

// Note - `i128`, rather than `u32`, because a cheat might make the time _longer_!
// (And we can't use i64 because the variable cheat-length is a usize, which is u64, so...:shrug:
fn scoreCheatWithVariableLength(cheat: Cheat, cheat_length: u64, base_lowest_time: u32, distances_from_start: std.AutoHashMap(Point, u32), distances_from_end: std.AutoHashMap(Point, u32), debug: bool) i128 {
    const distance_from_start = distances_from_start.get(cheat.start).?;
    const distance_from_end = distances_from_end.get(cheat.end).?;
    const total_time_with_cheat = distance_from_start + distance_from_end + cheat_length;
    log("DEBUG - total_time_with_cheat for {s} is {} - based on {} and {}\n", .{ cheat, total_time_with_cheat, distance_from_start, distance_from_end }, debug);
    return @as(i128, base_lowest_time) - @as(i128, total_time_with_cheat);
}

test "partTwo" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const response = try partTwo(true, true, allocator);
    print("Found {} sufficiently-speedy cheats for partTwo\n", .{response});
    try expect(response == 67);
}
