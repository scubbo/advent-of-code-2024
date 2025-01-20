const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");
const log = util.log;
const expect = std.testing.expect;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const response = try partTwo(false, false, allocator);
    print("{}\n", .{response});
}

fn partOne(is_test_case: bool, debug: bool, allocator: std.mem.Allocator) !u16 {
    const input_file = try util.getInputFile("19", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    var data_lines_it = std.mem.splitScalar(u8, data, '\n');
    const towels = parseTowels(data_lines_it.next().?, allocator);
    defer allocator.free(towels);

    _ = data_lines_it.next();

    var known_valid_designs = std.StringHashMap(void).init(allocator);
    defer known_valid_designs.deinit();
    // I added in this minor optimization because my code was running _super_ slow and I couldn't figure out why.
    // Then I realized I'd acccidentally left in a `std.time.sleep(1000000000)` that I'd introduced while debugging :P
    var known_invalid_designs = std.StringHashMap(void).init(allocator);
    defer known_invalid_designs.deinit();
    for (towels) |towel| {
        known_valid_designs.put(towel, {}) catch unreachable;
    }
    log("Parsed the towels\n", .{}, debug);

    var count: u16 = 0;
    while (data_lines_it.next()) |design| {
        if (isDesignValid(design, towels, &known_valid_designs, &known_invalid_designs, debug)) {
            count += 1;
        }
        print("Checked a design. Known valid designs now has size {}, and known invalid designs {}\n", .{ known_valid_designs.count(), known_invalid_designs.count() });
    }
    return count;
}

fn isDesignValid(design: []const u8, towels: [][]const u8, known_valid_designs: *std.StringHashMap(void), known_invalid_designs: *std.StringHashMap(void), debug: bool) bool {
    log("Checking validity of {s}, with {d} known valid designs and {d} known invalid designs\n", .{ design, known_valid_designs.count(), known_invalid_designs.count() }, debug);
    if (known_valid_designs.contains(design)) {
        log("***** Already found {s} to be a valid design *****\n", .{design}, debug);
        return true;
    }
    if (known_invalid_designs.contains(design)) {
        log("***** Already found {s} to be an INVALID design *****\n", .{design}, debug);
        return false;
    }
    for (towels) |towel| {
        if (design.len >= towel.len and std.mem.eql(u8, towel, design[0..towel.len])) {
            log("{s} is a valid prefix of {s}, so iterating down from there\n", .{ towel, design }, debug);
            const remainder = design[towel.len..];
            if (isDesignValid(remainder, towels, known_valid_designs, known_invalid_designs, debug)) {
                known_valid_designs.put(design, {}) catch unreachable;
                log("===== Adding {s} to known valid designs =====\n", .{design}, debug);
                return true;
            }
        }
    }
    known_invalid_designs.put(design, {}) catch unreachable;
    return false;
}

fn parseTowels(line: []const u8, allocator: std.mem.Allocator) [][]const u8 {
    var response = std.ArrayList([]const u8).init(allocator);
    var line_it = std.mem.splitSequence(u8, line, ", ");
    while (line_it.next()) |towel| {
        response.append(towel) catch unreachable;
    }
    return response.toOwnedSlice() catch unreachable;
}

// test "partOne" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     defer _ = gpa.deinit();
//     const allocator = gpa.allocator();

//     const response = try partOne(true, true, allocator);
//     print("Part One response is {}\n", .{response});
//     try expect(response == 6);
// }

fn partTwo(is_test_case: bool, debug: bool, allocator: std.mem.Allocator) !u128 {
    const input_file = try util.getInputFile("19", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    var data_lines_it = std.mem.splitScalar(u8, data, '\n');
    const towels = parseTowels(data_lines_it.next().?, allocator);
    defer allocator.free(towels);

    _ = data_lines_it.next();

    var ways_to_make_designs = std.StringHashMap(u128).init(allocator);
    defer ways_to_make_designs.deinit();
    // Not priming the "ways to make design" count, here, because this isn't as simple as the boolean yes-no in the
    // previous case - e.g. if we have towels `rbr`, `r`, and `br`, then the count for `rbr` should be 2, not 1.

    var count: u128 = 0;
    while (data_lines_it.next()) |design| {
        const ways = waysToMakeDesign(design, towels, &ways_to_make_designs, debug);
        print("Found {} ways to make {s}\n", .{ ways, design });
        count += ways;
    }
    return count;
}

fn waysToMakeDesign(design: []const u8, towels: [][]const u8, ways_to_make_designs: *std.StringHashMap(u128), debug: bool) u128 {
    if (design.len == 0) {
        return 1;
    }
    if (!(ways_to_make_designs.contains(design))) {
        var accum: u128 = 0;
        for (towels) |towel| {
            if (design.len >= towel.len and std.mem.eql(u8, towel, design[0..towel.len])) {
                const remainder = design[towel.len..];
                const response = waysToMakeDesign(remainder, towels, ways_to_make_designs, debug);
                if (response > 0) {
                    log("Got response {} to add to accum {} for remainder {s}\n", .{ response, accum, remainder }, debug);
                    accum += response;
                }
            }
        }
        ways_to_make_designs.put(design, accum) catch unreachable;
    }
    return ways_to_make_designs.get(design).?;
}

test "partTwo" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const response = try partTwo(true, true, allocator);
    print("Part Two response is {}\n", .{response});
    try expect(response == 16);
}
