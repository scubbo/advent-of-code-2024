const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");

pub fn main() !void {
    const response = try part_two(false);
    print("{}\n", .{response});
}

const Case = struct { test_value: u128, components: []u128, permitConcatentation: bool = false };

fn part_one(is_test_case: bool) !u128 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("07", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    // https://stackoverflow.com/a/79199470/1040915
    var it = std.mem.splitScalar(u8, data, '\n');
    var case_list = std.ArrayList(Case).init(allocator);
    defer case_list.deinit();

    while (it.next()) |line| {
        if (line.len > 1) {
            const case = try caseFromLine(line, allocator, false);
            try case_list.append(case);
        }
    }

    var returnValue: u128 = 0;
    for (case_list.items) |case| {
        if (try caseMatches(case, allocator)) {
            returnValue += case.test_value;
            allocator.free(case.components);
        }
    }
    return returnValue;
}

fn part_two(is_test_case: bool) !u128 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("07", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    // https://stackoverflow.com/a/79199470/1040915
    var it = std.mem.splitScalar(u8, data, '\n');
    var case_list = std.ArrayList(Case).init(allocator);
    defer case_list.deinit();

    while (it.next()) |line| {
        if (line.len > 1) {
            const case = try caseFromLine(line, allocator, true);
            try case_list.append(case);
        }
    }
    print("There are {} cases\n", .{case_list.items.len});

    var returnValue: u128 = 0;
    var idx: usize = 0;
    while (idx < case_list.items.len) : (idx += 1) {
        // for (case_list.items) |case| {
        const case = case_list.items[idx];
        if (idx % 10 == 0) {
            print("Checking case {}\n", .{idx});
        }
        if (try caseMatches(case, allocator)) {
            returnValue += case.test_value;
            allocator.free(case.components);
        }
    }
    return returnValue;
}

const ParsingError = error{NoTestValue};

fn caseFromLine(line: []const u8, allocator: std.mem.Allocator, permitConcatenation: bool) !Case {
    var components_list = std.ArrayList(u128).init(allocator);
    defer components_list.deinit();

    var values_it = std.mem.splitScalar(u8, line, ' ');
    const first_value = values_it.next();
    if (first_value == null) {
        return ParsingError.NoTestValue;
    }
    const first_value_without_colon = first_value.?[0 .. first_value.?.len - 1];
    // print("DEBUG - first_value_without_colon is ", .{});
    // for (first_value_without_colon) |c| {
    //     print("{c}", .{c});
    // }
    // print("\n", .{});
    const test_value = try std.fmt.parseInt(u128, first_value_without_colon, 10);

    while (values_it.next()) |val| {
        try components_list.append(try std.fmt.parseInt(u128, val, 10));
    }
    defer components_list.deinit();

    return Case{ .test_value = test_value, .components = try components_list.toOwnedSlice(), .permitConcatentation = permitConcatenation };
}

fn caseMatches(case: Case, allocator: std.mem.Allocator) !bool {
    if (case.components.len == 1) {
        return case.components[0] == case.test_value;
    } else {
        if (case.components[0] > case.test_value) {
            return false;
        }
        const addition_components = try allocator.alloc(u128, case.components.len - 1);
        const multiplication_components = try allocator.alloc(u128, case.components.len - 1);
        defer allocator.free(addition_components);
        defer allocator.free(multiplication_components);

        addition_components[0] = case.components[0] + case.components[1];
        // print("DEBUG - about to try multiplying {} and {}\n", .{ case.components[0], case.components[1] });
        multiplication_components[0] = case.components[0] * case.components[1];

        var idx: usize = 2;
        while (idx < case.components.len) : (idx += 1) {
            addition_components[idx - 1] = case.components[idx];
            multiplication_components[idx - 1] = case.components[idx];
        }

        const addition_case = Case{ .test_value = case.test_value, .components = addition_components, .permitConcatentation = case.permitConcatentation };
        const multiplication_case = Case{ .test_value = case.test_value, .components = multiplication_components, .permitConcatentation = case.permitConcatentation };

        // There's probably a neater way to do this, by adding options to an Array and then `or`-ing across them - but
        // what the hey, this isn't Python :P
        if (case.permitConcatentation) {
            // TODO - if we really cared about efficiency, we could have a repeated check of
            const concat_components = try allocator.alloc(u128, case.components.len - 1);
            defer allocator.free(concat_components);

            concat_components[0] = concatNumbers(case.components[0], case.components[1]);
            var idx_concat: usize = 2;
            while (idx_concat < case.components.len) : (idx_concat += 1) {
                concat_components[idx_concat - 1] = case.components[idx_concat];
            }
            const concat_case = Case{ .test_value = case.test_value, .components = concat_components, .permitConcatentation = case.permitConcatentation };
            return try caseMatches(addition_case, allocator) or try caseMatches(multiplication_case, allocator) or try caseMatches(concat_case, allocator);
        } else {
            return try caseMatches(addition_case, allocator) or try caseMatches(multiplication_case, allocator);
        }
    }
}

fn concatNumbers(num1: u128, num2: u128) u128 {
    const digits_in_num2 = std.math.log10_int(num2) + 1;
    return num1 * (std.math.pow(u128, 10, digits_in_num2)) + num2;
}

const expect = std.testing.expect;

test "part_one" {
    const part_one_response = try part_one(true);
    print("DEBUG - part_one_response is {}\n", .{part_one_response});
    try expect(part_one_response == 3749);
}

test "concatNumbers" {
    const five_and_two = concatNumbers(5, 2);
    print("DEBUG - five_and_two is {}\n", .{five_and_two});
    try expect(five_and_two == 52);
    try expect(concatNumbers(25, 32) == 2532);
    try expect(concatNumbers(1, 653) == 1653);
    try expect(concatNumbers(392, 1) == 3921);
}

test "part_two" {
    const part_two_response = try part_two(true);
    print("DEBUG - part_two_response is {}\n", .{part_two_response});
    try expect(part_two_response == 11387);
}
