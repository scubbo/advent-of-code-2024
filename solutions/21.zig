const std = @import("std");
const util = @import("util.zig");
const Point = util.Point;
const expect = std.testing.expect;

// Logic (after going down a rabbithole in `21_abandoned` that ended up having impractical runtime complexity):
// * Prefer moves that include doubles (because those will lead to shorter sequences on the "next level" because "A" can
// be pushed twice)
// * Other than that, picking moves is arbitrary - in particular, any moves on the numeric keypad can only ever have two
// directions (and they must be orthogonal to one another), which on the next-level directional keypad can only ever
// lead to the same amount of doubles no matter how they are arranged (e.g. `<<^^` will lead to the same number of
// doubles on the next-level keypad as `^^<<`)
// (I'd gotten all of that by myself, but was puzzled by one failing test case. I gave up and checked the internet
// for inspiration, and https://old.reddit.com/r/adventofcode/comments/1hj2odw/2024_day_21_solutions/m6qcv0f/ and
// https://old.reddit.com/r/adventofcode/comments/1hjgyps/2024_day_21_part_2_i_got_greedyish/ helped me realize that, in
// fact, moves _cannot_ be chosen arbitrarily because the lengths of resultant sequences _do_ diverge after repeated
// processing. Except where we have to pick moves to avoid the voids, we should always do moves in this order, <v^>)

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const strings = allocator.dupe([]const u8, &.{ "671A", "826A", "670A", "085A", "283A" }) catch unreachable;
    var total: u32 = 0;
    for (strings) |string| {
        total += findComplexityOfCode(string, allocator);
    }
    std.debug.print("Solution is {}\n", .{total});
}

fn findComplexityOfCode(code: []const u8, allocator: std.mem.Allocator) u32 {
    const length_of_sequence: u32 = @intCast(findLengthOfShortestResultOfLoopingNTimes(code, 3, allocator));
    const numeric_part = std.fmt.parseInt(u32, code[0 .. code.len - 1], 10) catch unreachable;
    return length_of_sequence * numeric_part;
}

fn findLengthOfShortestResultOfLoopingNTimes(originalNumericSequence: []const u8, times: usize, allocator: std.mem.Allocator) usize {
    const sequence = shortestDirectionalPushToEnterNumericSequence(originalNumericSequence, allocator);
    // defer allocator.free(sequence);

    var cur_sequences = std.StringHashMap(void).init(allocator);
    defer cur_sequences.deinit();
    cur_sequences.put(sequence, {}) catch unreachable;

    var next_sequences = std.StringHashMap(void).init(allocator);
    defer next_sequences.deinit();

    for (0..times - 1) |i| {
        std.debug.print("\nLooping for the {}-th time\n", .{i});
        var cur_it = cur_sequences.keyIterator();
        while (cur_it.next()) |n| {
            const next_level_entry = shortestDirectionalPushToEnterDirectionalSequence(n.*, allocator);
            next_sequences.put(next_level_entry, {}) catch unreachable;
        }

        cur_sequences.clearRetainingCapacity();
        var next_it = next_sequences.keyIterator();
        while (next_it.next()) |n| {
            cur_sequences.put(n.*, {}) catch unreachable;
        }
        next_sequences.clearRetainingCapacity();
    }

    var shortest_so_far: usize = std.math.maxInt(u32);
    var cur_it = cur_sequences.keyIterator();
    while (cur_it.next()) |c| {
        shortest_so_far = @min(c.*.len, shortest_so_far);
    }
    return shortest_so_far;
}

fn shortestDirectionalPushToEnterDirectionalSequence(directionalSequence: []const u8, allocator: std.mem.Allocator) []const u8 {
    //std.debug.print("Finding the shortest directional pushes to enter the directional sequence ", .{});
    printDirectionSeqAsDirections(directionalSequence);
    //std.debug.print("\n", .{});
    var cur_loc: u8 = 'A';
    var sequences_so_far = std.StringHashMap(void).init(allocator);
    defer sequences_so_far.deinit();
    sequences_so_far.put(allocator.dupe(u8, &.{}) catch unreachable, {}) catch unreachable;

    var new_candidate_sequences = std.StringHashMap(void).init(allocator);
    defer new_candidate_sequences.deinit();

    for (directionalSequence) |c| {
        const move = shortestSequenceToMoveDirectionalFromAToB(cur_loc, c, allocator);
        var move_with_enter = allocator.alloc(u8, move.len + 1) catch unreachable;
        for (move, 0..) |move_c, i| {
            move_with_enter[i] = move_c;
        }
        move_with_enter[move.len] = 65;
        allocator.free(move);

        var seq_it = sequences_so_far.keyIterator();
        while (seq_it.next()) |seq_so_far| {
            new_candidate_sequences.put(util.concatString(seq_so_far.*, move_with_enter) catch unreachable, {}) catch unreachable;
        }

        allocator.free(move_with_enter);

        cur_loc = c;
        sequences_so_far.clearRetainingCapacity();
        var cands_it = new_candidate_sequences.keyIterator();
        while (cands_it.next()) |next| {
            sequences_so_far.put(next.*, {}) catch unreachable;
        }
        new_candidate_sequences.clearRetainingCapacity();
    }

    expect(sequences_so_far.count() == 1) catch unreachable;

    var seq_it = sequences_so_far.keyIterator();
    while (seq_it.next()) |next| {
        return next.*;
    }
    unreachable;
}

// Unlike `...toMoveNumeric...`, `u8` here are the literal symbols on the keys
fn shortestSequenceToMoveDirectionalFromAToB(a: u8, b: u8, allocator: std.mem.Allocator) []const u8 {
    if (a == b) {
        return allocator.alloc(u8, 0) catch unreachable;
    }
    // Codes:
    // < = 60
    // > = 62
    // A = 65
    // ^ = 94
    // v = 118
    if (a > b) {
        const sequenceForBToA = shortestSequenceToMoveDirectionalFromAToB(b, a, allocator);
        const response = invertASequence(sequenceForBToA, allocator);
        allocator.free(sequenceForBToA);
        return response;
    }
    return switch (a) {
        '<' => switch (b) {
            '>' => allocator.dupe(u8, &.{ '>', '>' }) catch unreachable,
            'A' => allocator.dupe(u8, &.{ '>', '>', '^' }) catch unreachable,
            '^' => allocator.dupe(u8, &.{ '>', '^' }) catch unreachable,
            'v' => allocator.dupe(u8, &.{'>'}) catch unreachable,
            else => unreachable,
        },
        '>' => switch (b) {
            'A' => allocator.dupe(u8, &.{'^'}) catch unreachable,
            '^' => allocator.dupe(u8, &.{ '<', '^' }) catch unreachable,
            'v' => allocator.dupe(u8, &.{'<'}) catch unreachable,
            else => unreachable,
        },
        'A' => switch (b) {
            '^' => allocator.dupe(u8, &.{'<'}) catch unreachable,
            'v' => allocator.dupe(u8, &.{ '<', 'v' }) catch unreachable,
            else => unreachable,
        },
        '^' => switch (b) {
            'v' => allocator.dupe(u8, &.{'v'}) catch unreachable,
            else => unreachable,
        },
        else => unreachable,
    };
}

fn shortestDirectionalPushToEnterNumericSequence(numericSequence: []const u8, allocator: std.mem.Allocator) []const u8 {
    var cur_number: u8 = 10;
    // Keeping this as just a StringHashMap in carry-over from `21_abandoned`, even though there will only ever be a
    // single string at each stage.
    // But this way I don't have to worry about Zig's memory management with the fact that the "string" will change
    // size :P
    var sequences_so_far = std.StringHashMap(void).init(allocator);
    defer sequences_so_far.deinit();
    sequences_so_far.put(allocator.dupe(u8, &.{}) catch unreachable, {}) catch unreachable;

    var new_candidate_sequences = std.StringHashMap(void).init(allocator);
    defer new_candidate_sequences.deinit();

    for (numericSequence) |c| {
        //std.debug.print("Consuming {c} from numericSequence\n", .{c});
        const numericSequenceCharAsNumber = numericSequenceCharToNumber(c);
        const move = shortestSequenceToMoveNumericFromAToB(cur_number, numericSequenceCharAsNumber, allocator);
        //std.debug.print("DEBUG - moves are:\n", .{});
        // for (moves) |move| {
        //     printDirectionSeqAsDirections(move);
        //std.debug.print("\n", .{});
        // }
        var move_with_enter = allocator.alloc(u8, move.len + 1) catch unreachable;
        for (move, 0..) |move_c, i| {
            move_with_enter[i] = move_c;
        }
        move_with_enter[move.len] = 65;
        allocator.free(move);

        //std.debug.print("And with a trailing `A`, they are:\n", .{});
        // for (movesWithEnter) |move| {
        //     printDirectionSeqAsDirections(move);
        //std.debug.print("\n", .{});
        // }

        var seq_it = sequences_so_far.keyIterator();
        while (seq_it.next()) |seq_so_far| {
            // for (movesWithEnter) |new_moves| {
            //std.debug.print("About to concat these moves:", .{});
            // printDirectionSeqAsDirections(seq_so_far.*);
            //std.debug.print(", ", .{});
            // printDirectionSeqAsDirections(new_moves);
            //std.debug.print("\n", .{});
            new_candidate_sequences.put(util.concatString(seq_so_far.*, move_with_enter) catch unreachable, {}) catch unreachable;
            // }
        }
        // for (movesWithEnter) |new_moves| {
        //     allocator.free(new_moves);
        // }
        allocator.free(move_with_enter);

        // At this point, `new_candidate_sequences` contains all the new aggregated sequences - so, transfer them to
        // `sequences_so_far`.
        // TODO - not sure if I should be trimming to shortest _here_, or only at the end.
        cur_number = numericSequenceCharAsNumber;

        sequences_so_far.clearRetainingCapacity();
        var cands_it = new_candidate_sequences.keyIterator();
        while (cands_it.next()) |next| {
            sequences_so_far.put(next.*, {}) catch unreachable;
        }
        new_candidate_sequences.clearRetainingCapacity();
    }

    expect(sequences_so_far.count() == 1) catch unreachable;

    var seq_it = sequences_so_far.keyIterator();
    while (seq_it.next()) |next| {
        return next.*;
    }
    unreachable;
}

// Translates from "the Unicode number _of_ the number" to "the actual number" (or, from A=>10)
fn numericSequenceCharToNumber(numericSequenceChar: u8) u8 {
    return switch (numericSequenceChar) {
        48...57 => numericSequenceChar - 48,
        65 => 10,
        else => unreachable,
    };
}

// Use `10` to represent `A`
// If we wanted, we could introduce a `rotate` function to, say, define `1->6` in terms of `7->2` - but I think that's
// over-abstraction.
fn shortestSequenceToMoveNumericFromAToB(a: u8, b: u8, allocator: std.mem.Allocator) []const u8 {
    if (a == b) {
        return allocator.alloc(u8, 0) catch unreachable;
    }
    if (a > b) {
        const sequenceForBToA = shortestSequenceToMoveNumericFromAToB(b, a, allocator);
        const response = invertASequence(sequenceForBToA, allocator);
        allocator.free(sequenceForBToA);
        return response;
    }
    // Taking inspiration from https://ziggit.dev/t/how-to-free-or-identify-a-slice-literal/8188/3
    return switch (a) {
        0 => switch (b) {
            1 => allocator.dupe(u8, &.{ '^', '<' }) catch unreachable,
            2 => allocator.dupe(u8, &.{'^'}) catch unreachable,
            3 => allocator.dupe(u8, &.{ '^', '>' }) catch unreachable,
            4 => allocator.dupe(u8, &.{ '^', '^', '<' }) catch unreachable,
            5 => allocator.dupe(u8, &.{ '^', '^' }) catch unreachable,
            6 => allocator.dupe(u8, &.{ '^', '^', '>' }) catch unreachable,
            7 => allocator.dupe(u8, &.{ '^', '^', '^', '<' }) catch unreachable,
            8 => allocator.dupe(u8, &.{ '^', '^', '^' }) catch unreachable,
            9 => allocator.dupe(u8, &.{ '^', '^', '^', '>' }) catch unreachable,
            10 => allocator.dupe(u8, &.{'>'}) catch unreachable,
            else => unreachable,
        },
        1 => switch (b) {
            2 => allocator.dupe(u8, &.{'>'}) catch unreachable,
            3 => allocator.dupe(u8, &.{ '>', '>' }) catch unreachable,
            4 => allocator.dupe(u8, &.{'^'}) catch unreachable,
            5 => allocator.dupe(u8, &.{ '^', '>' }) catch unreachable,
            6 => allocator.dupe(u8, &.{ '^', '>', '>' }) catch unreachable,
            7 => allocator.dupe(u8, &.{ '^', '^' }) catch unreachable,
            8 => allocator.dupe(u8, &.{ '^', '^', '>' }) catch unreachable,
            9 => allocator.dupe(u8, &.{ '^', '^', '>', '>' }) catch unreachable,
            10 => allocator.dupe(u8, &.{ '>', '>', 'v' }) catch unreachable,
            else => unreachable,
        },
        2 => switch (b) {
            3 => allocator.dupe(u8, &.{'>'}) catch unreachable,
            4 => allocator.dupe(u8, &.{ '<', '^' }) catch unreachable,
            5 => allocator.dupe(u8, &.{'^'}) catch unreachable,
            6 => allocator.dupe(u8, &.{ '^', '>' }) catch unreachable,
            7 => allocator.dupe(u8, &.{ '<', '^', '^' }) catch unreachable,
            8 => allocator.dupe(u8, &.{ '^', '^' }) catch unreachable,
            9 => allocator.dupe(u8, &.{ '^', '^', '>' }) catch unreachable,
            10 => allocator.dupe(u8, &.{ 'v', '>' }) catch unreachable,
            else => unreachable,
        },
        3 => switch (b) {
            4 => allocator.dupe(u8, &.{ '<', '<', '^' }) catch unreachable,
            5 => allocator.dupe(u8, &.{ '<', '^' }) catch unreachable,
            6 => allocator.dupe(u8, &.{'^'}) catch unreachable,
            7 => allocator.dupe(u8, &.{
                '<',
                '<',
                '^',
                '^',
            }) catch unreachable,
            8 => allocator.dupe(u8, &.{ '<', '^', '^' }) catch unreachable,
            9 => allocator.dupe(u8, &.{ '^', '^' }) catch unreachable,
            10 => allocator.dupe(u8, &.{'v'}) catch unreachable,
            else => unreachable,
        },
        4 => switch (b) {
            5 => allocator.dupe(u8, &.{'>'}) catch unreachable,
            6 => allocator.dupe(u8, &.{ '>', '>' }) catch unreachable,
            7 => allocator.dupe(u8, &.{'^'}) catch unreachable,
            8 => allocator.dupe(u8, &.{ '>', '^' }) catch unreachable,
            9 => allocator.dupe(u8, &.{ '^', '>', '>' }) catch unreachable,
            10 => allocator.dupe(u8, &.{ '>', '>', 'v', 'v' }) catch unreachable,
            else => unreachable,
        },
        5 => switch (b) {
            6 => allocator.dupe(u8, &.{'>'}) catch unreachable,
            7 => allocator.dupe(u8, &.{ '^', '<' }) catch unreachable,
            8 => allocator.dupe(u8, &.{'^'}) catch unreachable,
            9 => allocator.dupe(u8, &.{ '^', '>' }) catch unreachable,
            10 => allocator.dupe(u8, &.{ 'v', 'v', '>' }) catch unreachable,
            else => unreachable,
        },
        6 => switch (b) {
            7 => allocator.dupe(u8, &.{ '<', '<', '^' }) catch unreachable,
            8 => allocator.dupe(u8, &.{ '<', '^' }) catch unreachable,
            9 => allocator.dupe(u8, &.{'^'}) catch unreachable,
            10 => allocator.dupe(u8, &.{ 'v', 'v' }) catch unreachable,
            else => unreachable,
        },
        7 => switch (b) {
            8 => allocator.dupe(u8, &.{'>'}) catch unreachable,
            9 => allocator.dupe(u8, &.{ '>', '>' }) catch unreachable,
            10 => allocator.dupe(u8, &.{ '>', '>', 'v', 'v', 'v' }) catch unreachable,
            else => unreachable,
        },
        8 => switch (b) {
            9 => allocator.dupe(u8, &.{'>'}) catch unreachable,
            10 => allocator.dupe(u8, &.{ 'v', 'v', 'v', '>' }) catch unreachable,
            else => unreachable,
        },
        9 => switch (b) {
            10 => allocator.dupe(u8, &.{ 'v', 'v', 'v' }) catch unreachable,
            else => unreachable,
        },
        else => unreachable,
    };
}

// To save having to type out _all_ the options above, only type out the ones where the number is increasing, then
// observe that "moving from A to B" is the same as "moving from B to A in reverse" - that is, taking the sequence of
// moves in reverse, and doing the opposite of each of them
fn invertASequence(sequence: []const u8, allocator: std.mem.Allocator) []u8 {
    var op = std.ArrayList(u8).init(allocator);
    var i: usize = sequence.len;
    while (i > 0) : (i -= 1) {
        switch (sequence[i - 1]) {
            '>' => op.append('<') catch unreachable,
            '^' => op.append('v') catch unreachable,
            '<' => op.append('>') catch unreachable,
            'v' => op.append('^') catch unreachable,
            else => unreachable,
        }
    }
    return op.toOwnedSlice() catch unreachable;
}

fn printDirectionSeqAsDirections(seq: []const u8) void {
    for (seq) |c| {
        std.debug.print("{c}", .{c});
    }
}

test "Shortest sequence for 0-loops" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const shortest_sequence = shortestDirectionalPushToEnterNumericSequence("029A", allocator);
    printDirectionSeqAsDirections(shortest_sequence);
}

test "Looping 3 times" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const min_length = findLengthOfShortestResultOfLoopingNTimes("029A", 3, allocator);
    std.debug.print("min_length is {}\n", .{min_length});
    try expect(min_length == 68);

    const min_length_1 = findLengthOfShortestResultOfLoopingNTimes("980A", 3, allocator);
    std.debug.print("min_length of 980A is {}\n", .{min_length_1});
    try expect(min_length_1 == 60);

    const min_length_2 = findLengthOfShortestResultOfLoopingNTimes("179A", 3, allocator);
    std.debug.print("min_length of 179A is {}\n", .{min_length_2});
    try expect(min_length_2 == 68);

    const min_length_3 = findLengthOfShortestResultOfLoopingNTimes("456A", 3, allocator);
    std.debug.print("min_length of 456A is {}\n", .{min_length_3});
    try expect(min_length_3 == 64);

    const min_length_4 = findLengthOfShortestResultOfLoopingNTimes("379A", 3, allocator);
    std.debug.print("min_length of 379A is {}\n", .{min_length_4});
    try expect(min_length_4 == 64);
}
