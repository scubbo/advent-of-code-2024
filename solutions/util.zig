// Unfortunately I have to put this in `solutions/` even though it more-properly belongs at a higher-level,
// because non-sibling imports require setting up a `build.zig` (https://old.reddit.com/r/Zig/comments/ra5qeo/import_of_file_outside_package_path/)
// and that seems awful.

const std = @import("std");
const print = std.debug.print;
const expect = @import("std").testing.expect;

pub fn getInputFile(problemNumber: []const u8, isTestCase: bool) ![]u8 {
    return concatString("inputs/", try concatString(problemNumber, try concatString("/", try concatString(if (isTestCase) "test" else "real", ".txt"))));
}

// Technically this could be implemented as just repeated calls to `concatString`, but I _guess_ this is more efficient?
// (I. Hate. Manual memory allocation)
pub fn concatStrings(strings: []const []const u8) ![]u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var totalLength: usize = 0;
    for (strings) |string| {
        totalLength += string.len;
    }
    var combined = try allocator.alloc(u8, totalLength);
    var combinedIndexSoFar: usize = 0;
    for (strings) |string| {
        @memcpy(combined[combinedIndexSoFar..(combinedIndexSoFar + string.len)], string);
        combinedIndexSoFar += string.len;
    }
    return combined;
}

pub fn concatString(a: []const u8, b: []const u8) ![]u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    // I don't recall where the below came from, but it causes a `[gpa] (err): memory address 0x10383f000 leaked:` when
    // kept in, so...dropping it! :P
    //
    // defer {
    //     const deinit_status = gpa.deinit();
    //     //fail test; can't try in defer as defer is executed after we return
    //     if (deinit_status == .leak) expect(false) catch @panic("TEST FAIL");
    // }

    return concat(u8, allocator, a, b);
}

// https://www.openmymind.net/Zigs-memcpy-copyForwards-and-copyBackwards/
fn concat(comptime T: type, allocator: std.mem.Allocator, arr1: []const T, arr2: []const T) ![]T {
    var combined = try allocator.alloc(T, arr1.len + arr2.len);
    @memcpy(combined[0..arr1.len], arr1);
    @memcpy(combined[arr1.len..], arr2);
    return combined;
}

// Ugh. There are a _ton_ of problems with this because of overflow nonsense - but it's good enough to use until
// test cases demonstrate that it's not.
pub fn diffOfNumbers(a: u32, b: u32) u32 {
    if (a > b) {
        return a - b;
    } else {
        return b - a;
    }
}

// I originally tried https://cookbook.ziglang.cc/01-01-read-file-line-by-line.html,
// but it's super-unwieldy.
// Stole https://codeberg.org/andyscott/advent-of-code/src/branch/main/2024/src/util.zig instead!
pub fn readAllInput(path: []u8) ![]const u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    std.debug.print("Path is {s}\n", .{path});
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    return try file.reader().readAllAlloc(alloc, stat.size);
}

pub fn readAllInputWithAllocator(path: []u8, alloc: std.mem.Allocator) ![]const u8 {
    std.debug.print("Path is {s}\n", .{path});
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    return try file.reader().readAllAlloc(alloc, stat.size);
}

pub fn magnitude(num: i32) u32 {
    if (num >= 0) {
        return @intCast(num);
    } else {
        return @intCast(-num);
    }
}

// These are used in so many of these types of puzzles - I should have just implemented them at the start, rather than
// so late in the challenge (Day 18 :P )
// (Though, in my defence, I didn't know what datatype would be appropriate, and I was quite a long way from being able
// to confidently use generics in Zig at that point)
pub const Point = struct {
    x: usize,
    y: usize,
    pub fn neighbours(self: *Point, width: usize, height: usize, allocator: std.mem.Allocator) []Point {
        var response = std.ArrayList(Point).init(allocator);
        if (self.x > 0) {
            response.append(Point{ .x = self.x - 1, .y = self.y }) catch unreachable;
        }
        if (self.y > 0) {
            response.append(Point{ .x = self.x, .y = self.y - 1 }) catch unreachable;
        }
        if (self.x < width - 1) {
            response.append(Point{ .x = self.x + 1, .y = self.y }) catch unreachable;
        }
        if (self.y < height - 1) {
            response.append(Point{ .x = self.x, .y = self.y + 1 }) catch unreachable;
        }

        return response.toOwnedSlice() catch unreachable;
    }

    pub fn format(self: Point, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("[{},{}]", .{ self.x, self.y });
    }
};

pub fn log(comptime message: []const u8, args: anytype, debug: bool) void {
    if (debug) {
        std.debug.print(message, args);
    }
}

// Basic implementation of Dijkstra - given start and end, explore until a shortest path is found to `end`.
// Assumes that all links have cost 1.
// Returns distances rather than the length of the path because that's often useful. In particular, pass `null` as `end`
// to get minimum distances from `start` to _every_ node.
//
// Zig does not really support the passing-in of bare anonymous functions that depend on higher-level variables - you'll
// get errors like `'<variable-name>' not accessible from inner function` or `crossing function boundary`.
//
// This appears to be a deliberate design decision to avoid unintentional use-after-free:
// https://ziggit.dev/t/closure-in-zig/5449
//
// So, instead of passing in a nicely-encapsulated partial-application `getNeighbours` which _just_ takes a `node_type`, it needs to take in the data as well. Blech.
//
// (Check out the implementation at commit `d85d29` to see what it looked like before this change!)
pub fn dijkstra(comptime data_type: type, comptime node_type: type, data: *const data_type, getNeighbours: *const fn (d: *const data_type, n: *node_type, allocator: std.mem.Allocator) []node_type, start: node_type, end: ?node_type, debug: bool, allocator: std.mem.Allocator) std.AutoHashMap(node_type, u32) {
    var visited = std.AutoHashMap(node_type, void).init(allocator);
    defer visited.deinit();

    var distances = std.AutoHashMap(node_type, u32).init(allocator);
    distances.put(start, 0) catch unreachable;

    // Not strictly necessary - we could just iterate over all keys of `distances` and filter out those that are
    // `visited` - but this certainly trims down the unnecessary debug logging, and I have an intuition (though haven't
    // proved) that it'll slightly help performance.
    var unvisited_candidates = std.AutoHashMap(node_type, void).init(allocator);
    defer unvisited_candidates.deinit();
    unvisited_candidates.put(start, {}) catch unreachable;

    while (true) {
        var cand_it = unvisited_candidates.keyIterator();
        var curr: node_type = undefined;
        var lowest_distance_found: u32 = std.math.maxInt(u32);
        while (cand_it.next()) |cand| {
            const actual_candidate = cand.*; // Necessary to avoid pointer weirdness
            log("Considering {s} as the next curr ", .{actual_candidate}, debug);

            const distance_of_candidate = distances.get(actual_candidate) orelse std.math.maxInt(u32);
            if (distance_of_candidate < lowest_distance_found) {
                log("and it is a possibility!\n", .{}, debug);
                curr = actual_candidate;
                lowest_distance_found = distance_of_candidate;
            } else {
                log("but rejecting it because it already has a shorter minimum-distance({} vs {})\n", .{ distance_of_candidate, lowest_distance_found }, debug);
            }
        }

        if (lowest_distance_found == std.math.maxInt(u32)) {
            log("Iterated over all candidates, but found none with non-infinite distance\n", .{}, debug);
            break;
        }
        log("Settled on {s} as the new curr", .{curr}, debug);

        if (end != null and std.meta.eql(curr, end.?)) {
            log(" and that is the target, so we're done!\n", .{}, debug);
            break;
        } else {
            log(" - now exploring its neighbours\n", .{}, debug);
        }

        // Haven't terminated yet => we're still looking. Check neighbours, and update their min-distance
        const distance_of_neighbour_from_current = lowest_distance_found + 1;
        const neighbours_of_curr = getNeighbours(data, &curr, allocator);
        for (neighbours_of_curr) |neighbour| {
            if (visited.contains(neighbour)) {
                continue;
            }

            const distance_response = distances.getOrPut(neighbour) catch unreachable;
            if (!distance_response.found_existing) {
                log("Adding a new (first) distance to {s} (via {s}) - {}\n", .{ neighbour, curr, distance_of_neighbour_from_current }, debug);
                distance_response.value_ptr.* = distance_of_neighbour_from_current;
                unvisited_candidates.put(neighbour, {}) catch unreachable;
            } else {
                if (distance_response.value_ptr.* > distance_of_neighbour_from_current) {
                    log("Overriding distance for neighbour {s} because distance of path from {s} ({}) is less than current value ({})\n", .{ neighbour, curr, distance_of_neighbour_from_current, distance_response.value_ptr.* }, debug);
                    distance_response.value_ptr.* = distance_of_neighbour_from_current;
                }
            }
        }
        allocator.free(neighbours_of_curr);
        visited.put(curr, {}) catch unreachable;
        _ = unvisited_candidates.remove(curr);
        log("{s} has now been fully visited - loop begins again\n", .{curr}, debug);
    }

    return distances;
}

test "Dijkstra" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // From AoC 2024 Day 20
    const base_data =
        \\###############
        \\#...#...#.....#
        \\#.#.#.#.#.###.#
        \\#.#...#.#.#...#
        \\#######.#.#.###
        \\#######.#.#...#
        \\#######.#.###.#
        \\###...#...#...#
        \\###.#######.###
        \\#...###...#...#
        \\#.#####.#.###.#
        \\#.#...#.#.#...#
        \\#.#.#.#.#.#.###
        \\#...#...#...###
        \\###############
    ;
    // This is absolutely fucking ridiculous - but I can't find a way to create a `*const []u8` from the above
    // `*const [N:0]u8`.
    // In particular, `std.mem.span` doesn't work, contra https://stackoverflow.com/a/72975237
    var data_list = std.ArrayList(u8).init(allocator);
    for (base_data) |c| {
        data_list.append(c) catch unreachable;
    }
    const data = data_list.toOwnedSlice() catch unreachable;
    defer allocator.free(data);
    const start = Point{ .x = 1, .y = 3 };
    const end = Point{ .x = 5, .y = 7 };

    const neighboursFunc = &struct {
        pub fn func(d: *const []u8, point: *Point, alloc: std.mem.Allocator) []Point {
            var response = std.ArrayList(Point).init(alloc);
            const ns = point.neighbours(15, 15, alloc);
            for (ns) |n| {
                if (d.*[16 * n.y + n.x] == '.') {
                    response.append(n) catch unreachable;
                }
            }
            alloc.free(ns);
            return response.toOwnedSlice() catch unreachable;
        }
    }.func;

    var result = dijkstra([]u8, Point, &data, neighboursFunc, start, end, false, allocator);
    defer result.deinit();
    const distance = result.get(end).?;
    print("Dijkstra result is {}\n", .{distance});
    try expect(distance == 84);
}

test {
    const result = try concatString("abc", "def");
    try expect(std.mem.eql(u8, result, "abcdef"));
}

test "concatStrings" {
    const result = try concatStrings(&.{ "hello ", "again, ", "friend of ", "a friend" });
    try expect(std.mem.eql(u8, result, "hello again, friend of a friend"));
}

test "testGetInputFile" {
    const result = try getInputFile("01", true);
    try expect(std.mem.eql(u8, result, "inputs/01/test.txt"));

    const result1 = try getInputFile("42", false);
    try expect(std.mem.eql(u8, result1, "inputs/42/real.txt"));
}

test "Test Diffing Numbers" {
    try expect(diffOfNumbers(5, 2) == 3);
    try expect(diffOfNumbers(26, 35) == 9);
    try expect(diffOfNumbers(5, 5) == 0);
}

test "Magnitude" {
    try expect(magnitude(2) == 2);
    try expect(magnitude(-2) == 2);
    try expect(magnitude(-365) == 365);
}
