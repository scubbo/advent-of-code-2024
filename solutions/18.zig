const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");
const log = util.log;
const Point = util.Point;
const expect = std.testing.expect;

// As of this day I started initializing the Allocator in `main` instead of `part_<whatever>` - the higher-level it is,
// the less repetition and (more importantly) the more likely I'll be able to deallocate anything returned from
// lower-level functions.
//
// Also while researching the previous day I realized how useful `catch unreachable` is for non-production-grade code
// like this - silently-swallowing irrelevant errors like `OutOfMemory`.
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const response = try partOne(false, false, allocator);
    print("{}\n", .{response});
}

fn partOne(is_test_case: bool, debug: bool, allocator: std.mem.Allocator) !u32 {
    if (debug) {
        print("DEBUG LOGGING IS ENABLED\n", .{});
    }
    const dimension: usize = if (is_test_case) 7 else 71;
    const data_volume: usize = if (is_test_case) 12 else 1024;

    const map = buildMap(dimension, allocator);
    defer allocator.free(map);
    defer {
        for (map) |line| {
            allocator.free(line);
        }
    }

    const input_file = try util.getInputFile("18", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    var data_lines_it = std.mem.splitScalar(u8, data, '\n');
    var count: usize = 0;
    while (data_lines_it.next()) |line| : (count += 1) {
        const comma_index = std.mem.indexOf(u8, line, ",").?;
        const x = std.fmt.parseInt(u8, line[0..comma_index], 10) catch unreachable;
        const y = std.fmt.parseInt(u8, line[comma_index + 1 ..], 10) catch unreachable;
        map[y][x] = '#';
        if (count >= data_volume - 1) {
            break;
        }
    }

    // For debugging purposes
    if (debug) {
        print("Printing the map for your own visualization:\n", .{});
        for (map) |line| {
            for (line) |c| {
                print("{c}", .{c});
            }
            print("\n", .{});
        }
    }

    // Hello Dijkstra my old friend...
    var visited = std.AutoHashMap(Point, void).init(allocator);
    defer visited.deinit();

    var distances = std.AutoHashMap(Point, u32).init(allocator);
    defer distances.deinit();
    distances.put(Point{ .x = 0, .y = 0 }, 0) catch unreachable;

    var candidates = std.AutoHashMap(Point, void).init(allocator);
    candidates.put(Point{ .x = 0, .y = 0 }, {}) catch unreachable;
    defer candidates.deinit();

    return while (true) {
        var cand_it = candidates.keyIterator();
        var current_point: Point = undefined;
        var lowest_distance_found: u32 = std.math.maxInt(u32);
        while (cand_it.next()) |cand| {
            const actual_point = cand.*;
            log("Considering {s} as the next current_point ", .{actual_point}, debug);
            if (visited.contains(actual_point)) {
                log("but rejecting it because it's been visited already\n", .{}, debug);
                continue;
            }

            const distance_of_candidate = distances.get(actual_point) orelse std.math.maxInt(u32);
            if (distance_of_candidate < lowest_distance_found) {
                log("and it is a possibility!\n", .{}, debug);
                current_point = actual_point;
                lowest_distance_found = distance_of_candidate;
            } else {
                log("but rejecting it because it already has a shorter minimum-distance ({} vs. {})\n", .{ distance_of_candidate, lowest_distance_found }, debug);
            }
        }

        log("Found point {s} as current_point - it has distance {}\n", .{ current_point, lowest_distance_found }, debug);
        if (lowest_distance_found == std.math.maxInt(u32)) {
            print("ERROR - iterated over all candidates, but found none with non-infinite distance\n", .{});
        }

        // Check for termination condition
        if (current_point.x == dimension - 1 and current_point.y == dimension - 1) {
            break lowest_distance_found;
        }

        // Haven't terminated => we're still on a non-target node. Check neighbours, and update their min-distance.

        const distance_of_neighbour_from_current_point = lowest_distance_found + 1;
        const neighbours = current_point.neighbours(dimension, dimension, allocator);
        for (neighbours) |neighbour| {
            if (visited.contains(neighbour)) {
                log("Not processing {s} because it's already been visited\n", .{neighbour}, debug);
                continue;
            }

            if (map[neighbour.y][neighbour.x] == '.') {
                const distance_response = distances.getOrPut(neighbour) catch unreachable;
                if (!distance_response.found_existing) {
                    log("Adding a new (first) distance to {s} (via {s}) - {}\n", .{ neighbour, current_point, distance_of_neighbour_from_current_point }, debug);
                    distance_response.value_ptr.* = distance_of_neighbour_from_current_point;
                } else {
                    if (distance_response.value_ptr.* > distance_of_neighbour_from_current_point) {
                        log("Overriding distance for neighbour {s} because distance of path from {s} ({}) is less than current value ({})\n", .{ neighbour, current_point, distance_of_neighbour_from_current_point, distance_response.value_ptr.* }, debug);
                        distance_response.value_ptr.* = distance_of_neighbour_from_current_point;
                    }
                }
                log("Adding {s} to candidates\n", .{neighbour}, debug);
                candidates.put(neighbour, {}) catch unreachable;
            } else {
                log("Not processing neighbour {s} because it is blocked off\n", .{neighbour}, debug);
            }
        }
        allocator.free(neighbours);

        // Update sets for next iteration
        visited.put(current_point, {}) catch unreachable;
        // Not strictly necessary, as we already check for visited whenever iterating over candidates - but this will
        // prevent some unnecessary double-processing.
        _ = candidates.remove(current_point);
    };
}

fn buildMap(dimension: usize, allocator: std.mem.Allocator) [][]u8 {
    var map_list = std.ArrayList([]u8).init(allocator);
    for (0..dimension) |_| {
        var line = std.ArrayList(u8).init(allocator);
        for (0..dimension) |_| {
            line.append('.') catch unreachable;
        }
        map_list.append(line.toOwnedSlice() catch unreachable) catch unreachable;
    }
    return map_list.toOwnedSlice() catch unreachable;
}

test "partOne" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const response = try partOne(true, true, allocator);
    print("Response is {}\n", .{response});
    try expect(response == 22);
}
