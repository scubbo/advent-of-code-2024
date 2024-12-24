const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");

pub fn main() !void {
    const output = try part_two(false);
    print("{}\n", .{output});
}

pub fn part_one(is_test_case: bool) !u32 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("05", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);

    // https://stackoverflow.com/a/79199470/1040915
    var it = std.mem.splitScalar(u8, data, '\n');
    var lines_list = std.ArrayList([]const u8).init(allocator);
    defer lines_list.deinit();

    var end_of_rules = false;
    var rules = std.ArrayList(Rule).init(allocator);
    defer rules.deinit();
    var updates = std.ArrayList(Update).init(allocator);
    defer updates.deinit();

    while (it.next()) |line| {
        if (line.len == 0) {
            end_of_rules = true;
            continue;
        }

        if (!end_of_rules) {
            try rules.append(try ruleFromLine(line));
        } else {
            const update = try updateFromLine(line, allocator);
            print("DEBUG - adding new update {any}\n", .{update.values});
            try updates.append(update);
        }
    }

    print("DEBUG - rules are:\n", .{});
    for (rules.items) |rule| { // Type annotations are weird here - ZLS reports `rule` as `[]const u8`, not `Rule`.
        print("{}|{}\n", .{ rule.first, rule.second });
    }
    print("DEBUG - length of updates is {}\n", .{updates.items.len});
    print("DEBUG - first update is {any}\n", .{updates.items[0]});

    var total: u32 = 0;
    for (updates.items) |update| {
        // I considered implementing a `fn all(comptime T: type, arr: []T, func: fn(t: T) bool) bool` to make this
        // more concise, but it looks like there's no simple way to make an anonymous function (so cannot pass in
        // `r.passes` as the function parameter)

        if (updatePassesAllRules(update, rules.items)) {
            total += getMiddleValueOfUpdate(update);
        }
    }
    return total;
}

const Rule = struct {
    first: u32,
    second: u32,

    fn passes(self: Rule, update: Update) bool {
        var second_encountered = false;
        for (update.values) |value| {
            if (value == self.second) {
                second_encountered = true;
            }
            if (value == self.first) {
                print("DEBUG - does update {any} pass rule {}|{}? {}\n", .{ update, self.first, self.second, !second_encountered });
                return !second_encountered;
            }
        }
        return true;
    }
};

fn updatePassesAllRules(update: Update, rules: []Rule) bool {
    for (rules) |rule| {
        print("DEBUG - checking {any} against {}|{}\n", .{ update.values, rule.first, rule.second });
        if (!rule.passes(update)) {
            return false;
        }
    }
    return true;
}

fn getMiddleValueOfUpdate(update: Update) u32 {
    return update.values[update.values.len / 2]; // Assumes that they're all of odd length.
}

fn ruleFromLine(line: []const u8) !Rule {
    var it = std.mem.splitScalar(u8, line, '|');
    const first = try std.fmt.parseInt(u32, it.next().?, 10);
    const second = try std.fmt.parseInt(u32, it.next().?, 10);
    return Rule{ .first = first, .second = second };
}

const Update = struct { values: []u32 };

fn updateFromLine(line: []const u8, allocator: std.mem.Allocator) !Update {
    print("DEBUG - processing line as update\n", .{});
    for (line) |c| {
        print("{c}", .{c});
    }
    print("\n", .{});

    var it = std.mem.splitScalar(u8, line, ',');
    var item_list = std.ArrayList(u32).init(allocator);
    // If this is commented-out, lots of memory-leaks are reported - but with this line in, a segmentation fault occurs
    // on referencing the result of this function.
    // defer item_list.deinit();

    while (it.next()) |item| {
        print("DEBUG - adding {any} to the item_list\n", .{item});
        try item_list.append(try std.fmt.parseInt(u32, item, 10));
    }
    print("DEBUG - items are {any}\n", .{item_list.items});
    const return_update = Update{ .values = item_list.items };
    print("DEBUG - return values are {any}\n", .{return_update.values});
    return return_update;
}

pub fn part_two(is_test_case: bool) !u32 {
    // I'm sure there's probably a better sorting logic here, but nothing's springing to mind, soooo we're going with...
    // * Identify all the incorrect updates. For each of them:
    //   * For every rule, if the rule fails, swap the elements that made it fail
    //   * Repeat until the whole set of rules pass
    // (I think this depends on Rules being consistent - i.e. if `a|b`, then there is no `b|a`. Which is a reasonable
    // assumption otherwise the problems are insoluble!)

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("05", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);

    // https://stackoverflow.com/a/79199470/1040915
    var it = std.mem.splitScalar(u8, data, '\n');
    var lines_list = std.ArrayList([]const u8).init(allocator);
    defer lines_list.deinit();

    var end_of_rules = false;
    var rules = std.ArrayList(Rule).init(allocator);
    defer rules.deinit();
    var updates = std.ArrayList(Update).init(allocator);
    defer updates.deinit();

    var total: u32 = 0;
    while (it.next()) |line| {
        if (line.len == 0) {
            end_of_rules = true;
            continue;
        }

        if (!end_of_rules) {
            try rules.append(try ruleFromLine(line));
        } else {
            var update = try updateFromLine(line, allocator);

            if (!updatePassesAllRules(update, rules.items)) {
                reorderUpdate(rules.items, &update);
                total += getMiddleValueOfUpdate(update);
            }
        }
    }
    return total;
}

fn reorderUpdate(rules: []Rule, update: *Update) void {
    var number_of_reorderings: usize = 0;
    while (reorderUpdateOnce(rules, update)) : (number_of_reorderings += 1) {
        print("DEBUG - reordered {} times\n", .{number_of_reorderings});
    }
}

// Ugh, I _hate_ modifying the argument to a function (rather than returning a new value) like some kind of C-using
// barbarian. But hey, when in Rome...
//
// Returns `true` if any changes were made
fn reorderUpdateOnce(rules: []Rule, update: *Update) bool {
    var changes_made = false;
    for (rules) |rule| {
        var have_encountered_second_value = false; // Have to use this because checking for `!= undefined` is itself UB.
        var index_of_second_value: usize = undefined;
        var idx: usize = 0;
        while (idx < update.values.len) : (idx += 1) {
            if (update.values[idx] == rule.second) {
                index_of_second_value = idx;
                have_encountered_second_value = true;
            }
            if (update.values[idx] == rule.first and have_encountered_second_value == true) {
                // Rule has been breached - swap the values, then continue with the next Rule
                update.values[idx] = rule.second;
                update.values[index_of_second_value] = rule.first;
                changes_made = true;
                break;
            }
        }
    }
    return changes_made;
}

const expect = std.testing.expect;

test "part_one" {
    const part_one_value = try part_one(true);
    print("DEBUG - part_one_value is {}\n", .{part_one_value});
    try expect(part_one_value == 143);
}

test "reordering" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var values1 = try allocator.alloc(u32, 5);
    defer allocator.free(values1);
    values1[0] = 75;
    values1[1] = 97;
    values1[2] = 47;
    values1[3] = 61;
    values1[4] = 53;
    var update1 = Update{ .values = values1 };

    var values2 = try allocator.alloc(u32, 3);
    defer allocator.free(values2);
    values2[0] = 61;
    values2[1] = 13;
    values2[2] = 29;
    var update2 = Update{ .values = values2 };

    var values3 = try allocator.alloc(u32, 5);
    defer allocator.free(values3);
    values3[0] = 97;
    values3[1] = 13;
    values3[2] = 75;
    values3[3] = 29;
    values3[4] = 47;
    var update3 = Update{ .values = values3 };

    const ruleText =
        \\47|53
        \\97|13
        \\97|61
        \\97|47
        \\75|29
        \\61|13
        \\75|53
        \\29|13
        \\97|29
        \\53|29
        \\61|53
        \\97|53
        \\61|29
        \\47|13
        \\75|47
        \\97|75
        \\47|61
        \\75|61
        \\47|29
        \\75|13
        \\53|13
    ;

    var it = std.mem.splitScalar(u8, ruleText, '\n');
    var rules = std.ArrayList(Rule).init(allocator);
    defer rules.deinit();
    while (it.next()) |line| {
        try rules.append(try ruleFromLine(line));
    }

    reorderUpdate(rules.items, &update1);
    try expect(update1.values[0] == 97);
    try expect(update1.values[1] == 75);
    try expect(update1.values[2] == 47);
    try expect(update1.values[3] == 61);
    try expect(update1.values[4] == 53);

    reorderUpdate(rules.items, &update2);
    try expect(update2.values[0] == 61);
    try expect(update2.values[1] == 29);
    try expect(update2.values[2] == 13);

    reorderUpdate(rules.items, &update3);
    try expect(update3.values[0] == 97);
    try expect(update3.values[1] == 75);
    try expect(update3.values[2] == 47);
    try expect(update3.values[3] == 29);
    try expect(update3.values[4] == 13);
}

test "part_two" {
    const part_two_value = try part_two(true);
    print("DEBUG - part_one_value is {}\n", .{part_two_value});
    try expect(part_two_value == 123);
}
