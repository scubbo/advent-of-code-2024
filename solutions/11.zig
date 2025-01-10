const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");

pub fn main() !void {
    const response = try part_two(false, 75);
    print("Response from running with 75 blinks is {}\n", .{response});
}

fn part_one(is_test_case: bool) anyerror!u128 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("11", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    var start_stones = try parseData(data, allocator);
    defer allocator.free(start_stones);

    for (0..25) |_| {
        start_stones = try blinkStones(start_stones, allocator);
        // print("DEBUG - after iteration {}, stones are {any}\n", .{ i, start_stones });
    }
    return start_stones.len;
}

fn parseData(data: []const u8, alloc: std.mem.Allocator) ![]u128 {
    var accum = std.ArrayList(u128).init(alloc);
    var it = std.mem.splitScalar(u8, data, ' ');
    while (it.next()) |chunk| {
        print("DEBUG - parsing {any} as int\n", .{chunk});
        try accum.append(try std.fmt.parseInt(u128, chunk, 10));
    }
    print("DEBUG - initial values are: ", .{});
    for (accum.items) |stone_value| {
        print("{} ", .{stone_value});
    }
    print("\n", .{});
    return accum.toOwnedSlice();
}

fn blinkStones(stones: []u128, alloc: std.mem.Allocator) ![]u128 {
    var accum = std.ArrayList(u128).init(alloc);
    for (stones) |stone| {
        const blinkedStones = try blinkStone(stone, alloc);
        for (blinkedStones) |blinked_stone| {
            try accum.append(blinked_stone);
        }
        alloc.free(blinkedStones);
    }
    alloc.free(stones);
    return accum.toOwnedSlice();
}

fn blinkStone(stone: u128, alloc: std.mem.Allocator) ![]u128 {
    // I don't like having to create an ArrayList here, but I don't know how to get around it:
    // `return []u128{1}` gives `array literal requires address-of operator (&) to coerce to slice type '[]u128'`
    // `return [_]u128{1}` gives the same error
    // `return [1]u128{1}` gives `expected type '[]u128', found '*const [1]u128'
    // And I can't declare the return type to be `[1]u128` because sometimes it's _not_ a single value
    var al = std.ArrayList(u128).init(alloc);
    if (stone == 0) {
        try al.append(1);
        return al.toOwnedSlice();
    }
    const number_of_digits_in_stone = std.math.log10_int(stone) + 1;
    // print("number of digits in {} is {}, ", .{ stone, number_of_digits_in_stone });
    if (number_of_digits_in_stone % 2 == 0) {
        // print("which is even, so splitting it\n", .{});
        const half_number_of_digits = @divExact(number_of_digits_in_stone, 2);
        const factor = std.math.pow(u128, 10, half_number_of_digits);
        try al.append(stone / factor);
        try al.append(stone % factor);
        return al.toOwnedSlice();
    } else {
        // print("which is odd, so multiplying it by 2024\n", .{});
        try al.append(stone * 2024);
        return al.toOwnedSlice();
    }
}

fn part_two(is_test_case: bool, blinks: u8) anyerror!u128 {
    // Heh, I suspected that this would just be an optimization question :P
    // Memoization ahoy!
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("11", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    const start_stones = try parseData(data, allocator);
    defer allocator.free(start_stones);

    var cache_data = std.AutoHashMap(Query, u128).init(allocator);
    defer cache_data.deinit();
    var cache = Cache{ .data = cache_data };

    var total: u128 = 0;
    for (start_stones) |stone| {
        total += try cache.get(Query{ .value = stone, .blinks = blinks }, allocator);
    }
    return total;
}

const Query = struct { value: u128, blinks: u8 };

const Cache = struct {
    data: std.AutoHashMap(Query, u128),
    fn get(self: *Cache, query: Query, alloc: std.mem.Allocator) !u128 {
        // "If you have a single stone with value `value`, how many stones will you have after `blinks` number of blinks?"
        if (query.blinks == 0) {
            return 1;
        }
        // A `getOrPut`-based solution - as outlined below - doesn't work. I'm _guessing_ this is because the
        // pointer is invalid after recursively calling `try self.get(Query{...})`, because _they_ will mutate the
        // HashMap, and so it's been "extended" such that the pointer doesn't point to the right place anymore.
        // ...this memory volatility is getting really annoying!
        // const response = try self.data.getOrPut(query);
        // if (response.found_existing) {
        //     return response.value_ptr.*;
        // } else {
        //     const blinked_stones = try blinkStone(query.value, alloc);
        //     var total: u32 = 0;
        //     for (blinked_stones) |blinked_stone| {
        //         total += try self.get(Query{ .value = blinked_stone, .blinks = query.blinks - 1 }, alloc);
        //     }
        //     response.value_ptr.* = total;
        //     alloc.free(blinked_stones);
        //     return total;
        // }
        //
        if (self.data.contains(query)) {
            return self.data.get(query).?;
        } else {
            const blinked_stones = try blinkStone(query.value, alloc);
            var total: u128 = 0;
            for (blinked_stones) |blinked_stone| {
                total += try self.get(Query{ .value = blinked_stone, .blinks = query.blinks - 1 }, alloc);
            }
            try self.data.put(query, total);
            alloc.free(blinked_stones);
            return total;
        }
    }
};

test "part_one" {
    const part_one_response = try part_one(true);
    print("DEBUG - part_one_response is {}\n", .{part_one_response});
    try std.testing.expect(part_one_response == 55312);
}

test "original_question_with_cache" {
    const with_cache_response = try part_two(true, 25);
    print("DEBUG - with_cache response is {}\n", .{with_cache_response});
    try std.testing.expect(with_cache_response == 55312);
}
