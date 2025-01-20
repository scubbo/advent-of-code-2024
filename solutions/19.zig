const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");
const log = util.log;
const expect = std.testing.expect;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const response = try partOne(false, false, allocator);
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

test "partOne" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const response = try partOne(true, true, allocator);
    print("Part One response is {}\n", .{response});
    try expect(response == 6);
}
