// It seems like the goal of the program is just to multiply some numbers. It does that with instructions like mul(X,Y), where X and Y are each 1-3 digit numbers. For instance, mul(44,46) multiplies 44 by 46 to get a result of 2024. Similarly, mul(123,4) would multiply 123 by 4.

// However, because the program's memory has been corrupted, there are also many invalid characters that should be ignored, even if they look like part of a mul instruction. Sequences like mul(4*, mul(6,9!, ?(12,34), or mul ( 2 , 4 ) do nothing.

// For example, consider the following section of corrupted memory:

// xmul(2,4)%&mul[3,7]!@^do_not_mul(5,5)+mul(32,64]then(mul(11,8)mul(8,5))

// Only the four highlighted sections are real mul instructions. Adding up the result of each instruction produces 161 (2*4 + 5*5 + 11*8 + 8*5).

// Scan the corrupted memory for uncorrupted mul instructions. What do you get if you add up all of the results of the multiplications?

const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");

pub fn main() !void {
    const output = try part_two();
    print("{}\n", .{output});
}

pub fn part_one() !u32 {
    // Sketch logic:
    // * Iterate over lines of the file
    // * For each character, drop into a sub-function, which
    //   * Progresses and checks if this is a valid multiplication command
    //   * If it is, multiply it and return the value (to be summed to accumulator)
    //   * Else, return 0
    // (A micro-optimization would be to also return the number of characters consumed so that the pointer could advance
    // by that much and not recheck each of the characters within the `mul` statement for being the start of a statement)
    
    const isTestCase: bool = true;
    const data = try util.readAllInput(try util.getInputFile("03", isTestCase));
    var total: u32 = 0;
    var idx: u32 = 0;
    while (idx < data.len) {
        total += check_if_is_valid_multiplication(data, idx);
        idx += 1;
    }
    return total;
    
}

pub fn part_two() !u32 {
    const isTestCase: bool = true;
    var should_mul = true;
    const data = try util.readAllInput(try util.getInputFile("03", isTestCase));
    var total: u32 = 0;
    var idx: u32 = 0;
    while (idx < data.len) {
        // As elsewhere - there are probably plenty of optimizations to be done here, such as only checking for `d`
        // first to avoid checking the whole 4 bytes. Lol :P
        if (idx+4 < data.len and std.mem.eql(u8, data[idx..idx+4], "do()")) {
            should_mul = true;
            idx += 1;
            continue;
        }
        if (idx+7 < data.len and std.mem.eql(u8, data[idx..idx+7], "don't()")) {
            should_mul = false;
            idx += 1;
            continue;
        }
        if (should_mul) {
            total += check_if_is_valid_multiplication(data, idx);
        }
        idx += 1;
    }
    return total;
}

fn check_if_is_valid_multiplication(line: []const u8, start_index: u32) u32 {
    // Check starts with `mul(`
    // Check for matching close paren
    // Check that the contents of the parens are three numbers
    //
    // If any of these false, return 0
    // Else, do multiplication and return appropriate value
    if (line[start_index] != 'm') {
        // print("DEBUG - does not start with m\n", .{});
        return 0;
    }
    if ((start_index + 6) > line.len) {
        // print("DEBUG - too close to the end\n", .{});
        return 0;
    }

    if (!std.mem.eql(u8, line[start_index..start_index+4], "mul(")) {
        return 0;
    }
    if (line[start_index+4] == ')') {
        // I.e. if `mul()`
        // print("DEBUG - content is mul()", .{});
        return 0;
    }
    // Progress from index after the open-paren, to find the close-paren.
    var i: u32 = 1;
    var length_of_parameters: u32 = 0;
    var index_of_comma: u32 = 0;
    while (i < 12) {
        if (line[start_index+i] == ')') {
            length_of_parameters = i;
            break;
        }
        if (line[start_index+i] == ',') {
            index_of_comma = i;
        }
        i += 1;
    }
    if (length_of_parameters == 0) {
        // Did not find a close-paren
        // print("DEBUG - did not find a close-paren\n", .{});
        return 0;
    }
    if (index_of_comma == 0) {
        // Did not find comma
        // print("DEBUG - did not find a comma\n", .{});
        return 0;
    }
    // This is _almost_ guaranteed to be a legal multiplication command - we know it has the form
    // `mul(...,...)`. Try parsing the `...`s as ints - and if they don't parse, return 0
    const num_1 = std.fmt.parseInt(u32, line[start_index+4..start_index+index_of_comma], 10) catch {
        print("DEBUG - failed to parse first value into an integer: ", .{});
        for (line[start_index..start_index+index_of_comma]) |char| {
            print("{c}", .{char});
        }
        print("\n", .{});
        return 0;
    };
    const num_2 = std.fmt.parseInt(u32, line[start_index+index_of_comma+1..start_index+length_of_parameters], 10) catch {
        print("DEBUG - failed to parse second value into an integer: ", .{});
        for (line[start_index+index_of_comma+1..start_index+length_of_parameters]) |char| {
            print("{c}", .{char});
        }
        print("\n", .{});
        return 0;
    };
    print("DEBUG - found a real pair, {} and {}\n", .{num_1, num_2});
    return num_1 * num_2;
}

const expect = @import("std").testing.expect;

test "Testing multiplication" {
    const line = "mul() mul(2,3) is mu mul(2*,2), mul(2343,213) mul(231,123";
    try expect(check_if_is_valid_multiplication(try fromStringToU8Array(line), 0) == 0);
    try expect(check_if_is_valid_multiplication(try fromStringToU8Array(line), 6) == 6);
}

// This is absolutely fucking ridiculous - but, simply doing `<variable>.*` doesn't work.
fn fromStringToU8Array(string: *const[57:0]u8) ![]u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var output = std.ArrayList(u8).init(allocator);
    for (string) |char| {
        try output.append(char);
    }
    // This "leaks memory", but I don't know how _not_ to - the alternative would be to create an array into which to
    // copy `output.items`, but you _can't_ do that because `output.items.len` isn't known at comptime.
    return output.items;
}

test "Part One" {
    try expect(try part_one() == 161);
}