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

    const response = try partOne(false, false, allocator);
    print("{}\n", .{response});
}

// Sketch of intended logic:
// * Find shortest non-cheating time start-to-finish
// * Find fastest time (don't need to save path) from start _to_ each location
// * Find faster time (ditto) from end _to_ each location
// * Find all cheats
// * For each cheat:
//   * Time saved is basic time - (time-from-start-to-start-of-cheat - time-from-end-of-cheat-to-end)
//
// Implementation is not yet complete! So far I've only implemented the first bullet, because building a generic
// implementation of Dijkstra's was an _ARSE_ - the rest can happen tomorrow!
fn partOne(is_test_case: bool, debug: bool, allocator: std.mem.Allocator) !u32 {
    const input_file = try util.getInputFile("20", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    const map = buildMap(data, allocator);
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

    const shortestPathLength = util.dijkstra([][]u8, Point, &map, neighboursFunc, start_point, end_point, debug, allocator) catch unreachable;
    return shortestPathLength;
}

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
    print("{}\n", .{response});
    try expect(response == 84);
}
