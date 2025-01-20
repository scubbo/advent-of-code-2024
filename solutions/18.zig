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

    const response = try partTwo(false, false, allocator);
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

// Outline of logic:
// * (Without any bytes fallen) find the shortest path. Make sure you note the _path_, not just the length
// * Repeatedly:
//   * Let bytes fall until one falls _on_ the shortest-path
//   * Calculate the new shortest path. If none exists, the last byte that fell is the answer
//
// ...having implemented this, I now realize there's probably a faster way to do this - add bytes until there is a
// single path _on blocked bytes_ from the left-and-bottom edges to top-and-right edges (allowing for diagonals). Ah
// well - this reuses already-written code!
fn partTwo(is_test_case: bool, debug: bool, allocator: std.mem.Allocator) !Point {
    if (debug) {
        print("DEBUG LOGGING IS ENABLED\n", .{});
    }
    const dimension: usize = if (is_test_case) 7 else 71;

    var map = buildMap(dimension, allocator);
    defer allocator.free(map);
    defer {
        for (map) |line| {
            allocator.free(line);
        }
    }

    const input_file = try util.getInputFile("18", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    var data_it = std.mem.splitScalar(u8, data, '\n');
    defer allocator.free(data);

    var bytes_fallen: usize = 0;
    var last_fallen_byte: Point = undefined;
    while (true) {
        std.time.sleep(1000000000);
        const maybe_shortest_path = findShortestPath(map, dimension, debug, allocator);
        if (maybe_shortest_path) |shortest_path| {
            // Ditto below - want this to show up even if we have debug off for Dijkstra
            print("Found a shortest path: ", .{});

            var path_it = shortest_path.keyIterator();
            while (path_it.next()) |point| {
                print("{s},", .{point});
            }
            print("\n", .{});
            while (data_it.next()) |line| : (bytes_fallen += 1) {
                const comma_index = std.mem.indexOf(u8, line, ",").?;
                const x = std.fmt.parseInt(u8, line[0..comma_index], 10) catch unreachable;
                const y = std.fmt.parseInt(u8, line[comma_index + 1 ..], 10) catch unreachable;
                const byte_point = Point{ .x = x, .y = y };
                last_fallen_byte = byte_point;
                map[y][x] = '#';
                print("Blocking {s} in map\n", .{byte_point});
                if (shortest_path.contains(byte_point)) {
                    // This falling byte has caused a shortest-path to be blocked - recalculate
                    // This could arguably be `log`, but I want to see this even without the debug-logging of the Dijkstra
                    print("After the fall of the {}-th byte ({s}), the shortest path was blocked. Recalculating\n", .{ bytes_fallen + 1, byte_point });
                    bytes_fallen += 1;
                    // There _must_ be a better way to do this!? But without an intermediate variable, `shortest_path`
                    // is `*const`, meaning it can't be `deinit`ed
                    var pointer_to_shortest_path = shortest_path;
                    pointer_to_shortest_path.deinit();
                    break;
                }
            }
        } else {
            // No shortest-path could be found
            print("Could not find a shortest path\n", .{});
            break;
        }
    }
    return last_fallen_byte;
}

// Technically this finds "the set of Points that are on _a_ shortest-path" - which is fine for our purposes, as we're
// only trying to (eventually) find the case where _all_ paths are cut off. So, a byte that cuts off _any_ shortest-path
// is valid to trigger a recalculation, even if the other shortest-path is still valid - we'll just recalculate to find
// that one (then continue).
fn findShortestPath(map: [][]const u8, dimension: usize, debug: bool, allocator: std.mem.Allocator) ?std.AutoHashMap(Point, void) {
    if (true) { // Should really be `if debug` but we don't have enough specificity in that.
        print("Finding shortest path in the following map:\n", .{});
        for (map) |line| {
            for (line) |c| {
                print("{c}", .{c});
            }
            print("\n", .{});
        }
    }
    var visited = std.AutoHashMap(Point, void).init(allocator);
    defer visited.deinit();

    var distances = std.AutoHashMap(Point, u32).init(allocator);
    defer distances.deinit();
    distances.put(Point{ .x = 0, .y = 0 }, 0) catch unreachable;

    var candidates = std.AutoHashMap(Point, void).init(allocator);
    candidates.put(Point{ .x = 0, .y = 0 }, {}) catch unreachable;
    defer candidates.deinit();

    const length_of_path = while (true) {
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
            break lowest_distance_found;
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
    if (length_of_path == std.math.maxInt(u32)) {
        // No path exists
        return null;
    }

    // At this point, `distances` contains enough distances to trace a shortest-path - now just have to traceback.
    var shortest_path = std.AutoHashMap(Point, void).init(allocator);
    var current_point: Point = Point{ .x = dimension - 1, .y = dimension - 1 };
    var current_distance = length_of_path;
    while (!(current_point.x == 0 and current_point.y == 0)) {
        shortest_path.put(current_point, {}) catch unreachable;
        const neighbours = current_point.neighbours(dimension, dimension, allocator);
        for (neighbours) |neighbour| {
            if (distances.get(neighbour) orelse std.math.maxInt(u32) == current_distance - 1) {
                current_point = neighbour;
                current_distance -= 1;
                break;
            }
        }
        allocator.free(neighbours);
    }
    shortest_path.put(Point{ .x = 0, .y = 0 }, {}) catch unreachable;
    return shortest_path;
}

test "partTwo" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const response = try partTwo(true, false, allocator);
    print("Response is {}\n", .{response});
    try expect(response.x == 6 and response.y == 1);
}
