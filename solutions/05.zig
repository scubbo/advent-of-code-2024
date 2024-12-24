const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");

pub fn main() !void {
    const output = try part_one(false);
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

const expect = std.testing.expect;

test "part_one" {
    const part_one_value = try part_one(true);
    print("DEBUG - part_one_value is {}\n", .{part_one_value});
    try expect(part_one_value == 143);
}
