const std = @import("std");
const util = @import("util.zig");
const Point = util.Point;
const expect = std.testing.expect;

// This seems like a deceptively simple problem.
// At first glance it'd seem like you could take some shortcuts - instead of gathering _all_ possible routes from one
// button to another, and iterating on them, just pick _one_ route. That way, the number of strings being processed
// doesn't grow exponentially.
// Unfortunately I don't think it's that simple - "<<^" and "<^<" will result in a different length of "next-level"
// instructions, because repeated pushes of the same button result in shorter instructions (just repush the "A" button
// at the next layer up)
// But we can't just bias for repetition within a single move, because there might be repetition across moves:
// `v< | <^< | <v`, for instance, has two "doublings-up", across a move-boundary, even though no move contains repeated
// pushes.
// Although...actually, all moves are going to be suffixed by `A` anyway, so maybe that's not actually accurate and I
// should just try biasing for repetition?
// I've already written too much in this file to really be able to refactor it - I'm going to rename this to
// `21_abandoned` and start afresh.

fn findLengthOfShortestResultOfLoopingNTimes(originalNumericSequence: []const u8, times: usize, allocator: std.mem.Allocator) usize {
    const sequences = shortestDirectionalPushesToEnterNumericSequence(originalNumericSequence, allocator);
    defer allocator.free(sequences);

    var cur_sequences = std.StringHashMap(void).init(allocator);
    defer cur_sequences.deinit();
    for (sequences) |seq| {
        cur_sequences.put(seq, {}) catch unreachable;
    }

    var next_sequences = std.StringHashMap(void).init(allocator);
    defer next_sequences.deinit();

    for (0..times) |i| {
        std.debug.print("Looping for the {}-th time\n", .{i});
        var cur_it = cur_sequences.keyIterator();
        while (cur_it.next()) |n| {
            const next_level_entries = shortestDirectionalPushesToEnterDirectionalSequence(n.*, allocator);
            for (next_level_entries) |nle| {
                next_sequences.put(nle, {}) catch unreachable;
            }
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

fn shortestDirectionalPushesToEnterDirectionalSequence(directionalSequence: []const u8, allocator: std.mem.Allocator) []const []const u8 {
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
        const moves = shortestSequencesToMoveDirectionalFromAToB(cur_loc, c, allocator);
        //std.debug.print("For a move from {c} to {c}, found options:\n", .{ cur_loc, c });
        for (moves) |move| {
            printDirectionSeqAsDirections(move);
            //std.debug.print("\n", .{});
        }
        const movesWithEnter = if (moves.len == 0)
            allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'A'}) catch unreachable}) catch unreachable
        else
            appendSequencesWith(moves, 65, allocator);
        //std.debug.print("And after adding enter, they are:\n", .{});
        for (movesWithEnter) |move| {
            printDirectionSeqAsDirections(move);
            //std.debug.print("\n", .{});
        }

        var seq_it = sequences_so_far.keyIterator();
        while (seq_it.next()) |seq_so_far| {
            for (movesWithEnter) |new_moves| {
                new_candidate_sequences.put(util.concatString(seq_so_far.*, new_moves) catch unreachable, {}) catch unreachable;
            }
        }

        for (movesWithEnter) |new_moves| {
            allocator.free(new_moves);
        }
        allocator.free(movesWithEnter);

        cur_loc = c;
        sequences_so_far.clearRetainingCapacity();
        var cands_it = new_candidate_sequences.keyIterator();
        while (cands_it.next()) |next| {
            sequences_so_far.put(next.*, {}) catch unreachable;
        }
        new_candidate_sequences.clearRetainingCapacity();
    }

    var response = std.ArrayList([]const u8).init(allocator);
    var seq_it = sequences_so_far.keyIterator();
    while (seq_it.next()) |next| {
        response.append(next.*) catch unreachable;
    }
    return response.toOwnedSlice() catch unreachable;
}

// Unlike `...toMoveNumeric...`, `u8` here are the literal symbols on the keys
fn shortestSequencesToMoveDirectionalFromAToB(a: u8, b: u8, allocator: std.mem.Allocator) []const []const u8 {
    if (a == b) {
        return allocator.alloc([]u8, 0) catch unreachable;
    }
    // Codes:
    // < = 60
    // > = 62
    // A = 65
    // ^ = 94
    // v = 118
    if (a > b) {
        const sequencesForBToA = shortestSequencesToMoveDirectionalFromAToB(b, a, allocator);
        var op = std.ArrayList([]u8).init(allocator);
        for (sequencesForBToA) |sequence| {
            op.append(invertASequence(sequence, allocator)) catch unreachable;
            allocator.free(sequence);
        }
        allocator.free(sequencesForBToA);
        return op.toOwnedSlice() catch unreachable;
    }
    return switch (a) {
        '<' => switch (b) {
            '>' => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{ '>', '>' }) catch unreachable}) catch unreachable,
            'A' => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '>', '>', '^' }) catch unreachable, allocator.dupe(u8, &.{ '>', '^', '>' }) catch unreachable }) catch unreachable,
            '^' => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{ '>', '^' }) catch unreachable}) catch unreachable,
            'v' => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'>'}) catch unreachable}) catch unreachable,
            else => unreachable,
        },
        '>' => switch (b) {
            'A' => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'^'}) catch unreachable}) catch unreachable,
            '^' => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '<', '^' }) catch unreachable, allocator.dupe(u8, &.{ '^', '<' }) catch unreachable }) catch unreachable,
            'v' => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'<'}) catch unreachable}) catch unreachable,
            else => unreachable,
        },
        'A' => switch (b) {
            '^' => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'<'}) catch unreachable}) catch unreachable,
            'v' => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ 'v', '<' }) catch unreachable, allocator.dupe(u8, &.{ '<', 'v' }) catch unreachable }) catch unreachable,
            else => unreachable,
        },
        '^' => switch (b) {
            'v' => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'v'}) catch unreachable}) catch unreachable,
            else => unreachable,
        },
        else => unreachable,
    };
}

fn shortestDirectionalPushesToEnterNumericSequence(numericSequence: []const u8, allocator: std.mem.Allocator) []const []const u8 {
    var cur_number: u8 = 10;
    var sequences_so_far = std.StringHashMap(void).init(allocator);
    defer sequences_so_far.deinit();
    sequences_so_far.put(allocator.dupe(u8, &.{}) catch unreachable, {}) catch unreachable;

    var new_candidate_sequences = std.StringHashMap(void).init(allocator);
    defer new_candidate_sequences.deinit();

    for (numericSequence) |c| {
        //std.debug.print("Consuming {c} from numericSequence\n", .{c});
        const numericSequenceCharAsNumber = numericSequenceCharToNumber(c);
        const moves = shortestSequencesToMoveNumericFromAToB(cur_number, numericSequenceCharAsNumber, allocator);
        //std.debug.print("DEBUG - moves are:\n", .{});
        for (moves) |move| {
            printDirectionSeqAsDirections(move);
            //std.debug.print("\n", .{});
        }
        const movesWithEnter = appendSequencesWith(moves, 65, allocator);
        //std.debug.print("And with a trailing `A`, they are:\n", .{});
        for (movesWithEnter) |move| {
            printDirectionSeqAsDirections(move);
            //std.debug.print("\n", .{});
        }

        var seq_it = sequences_so_far.keyIterator();
        while (seq_it.next()) |seq_so_far| {
            for (movesWithEnter) |new_moves| {
                //std.debug.print("About to concat these moves:", .{});
                printDirectionSeqAsDirections(seq_so_far.*);
                //std.debug.print(", ", .{});
                printDirectionSeqAsDirections(new_moves);
                //std.debug.print("\n", .{});
                new_candidate_sequences.put(util.concatString(seq_so_far.*, new_moves) catch unreachable, {}) catch unreachable;
            }
        }
        for (movesWithEnter) |new_moves| {
            allocator.free(new_moves);
        }
        allocator.free(movesWithEnter);

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

    var response = std.ArrayList([]const u8).init(allocator);
    var seq_it = sequences_so_far.keyIterator();
    while (seq_it.next()) |next| {
        response.append(next.*) catch unreachable;
    }
    return response.toOwnedSlice() catch unreachable;
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
fn shortestSequencesToMoveNumericFromAToB(a: u8, b: u8, allocator: std.mem.Allocator) []const []const u8 {
    if (a == b) {
        return allocator.alloc([]u8, 0) catch unreachable;
    }
    if (a > b) {
        const sequencesForBToA = shortestSequencesToMoveNumericFromAToB(b, a, allocator);
        var op = std.ArrayList([]u8).init(allocator);
        for (sequencesForBToA) |sequence| {
            op.append(invertASequence(sequence, allocator)) catch unreachable;
            allocator.free(sequence);
        }
        allocator.free(sequencesForBToA);
        return op.toOwnedSlice() catch unreachable;
    }
    // Taking inspiration from https://ziggit.dev/t/how-to-free-or-identify-a-slice-literal/8188/3
    return switch (a) {
        0 => switch (b) {
            1 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{ '^', '<' }) catch unreachable}) catch unreachable,
            2 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'^'}) catch unreachable}) catch unreachable,
            3 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '>' }) catch unreachable, allocator.dupe(u8, &.{ '>', '^' }) catch unreachable }) catch unreachable,
            4 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '^', '<' }) catch unreachable, allocator.dupe(u8, &.{ '^', '<', '^' }) catch unreachable }) catch unreachable,
            5 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{ '^', '^' }) catch unreachable}) catch unreachable,
            6 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '^', '>' }) catch unreachable, allocator.dupe(u8, &.{ '^', '>', '^' }) catch unreachable, allocator.dupe(u8, &.{ '>', '^', '^' }) catch unreachable }) catch unreachable,
            7 => {
                const twoToSeven = shortestSequencesToMoveNumericFromAToB(2, 7, allocator);
                return prependSequencesWith(twoToSeven, '^', allocator);
            },
            8 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{ '^', '^', '^' }) catch unreachable}) catch unreachable,
            9 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '^', '^', '>' }) catch unreachable, allocator.dupe(u8, &.{ '^', '^', '>', '^' }) catch unreachable, allocator.dupe(u8, &.{ '^', '>', '^', '^' }) catch unreachable, allocator.dupe(u8, &.{ '>', '^', '^', '^' }) catch unreachable }) catch unreachable,
            10 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'>'}) catch unreachable}) catch unreachable,
            else => unreachable,
        },
        1 => switch (b) {
            0 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{ '>', 'v' }) catch unreachable}) catch unreachable,
            2 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'>'}) catch unreachable}) catch unreachable,
            3 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{ '>', '>' }) catch unreachable}) catch unreachable,
            4 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'^'}) catch unreachable}) catch unreachable,
            5 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '>' }) catch unreachable, allocator.dupe(u8, &.{ '>', '^' }) catch unreachable }) catch unreachable,
            6 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '>', '>' }) catch unreachable, allocator.dupe(u8, &.{ '>', '^', '>' }) catch unreachable, allocator.dupe(u8, &.{ '>', '>', '^' }) catch unreachable }) catch unreachable,
            7 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{ '^', '^' }) catch unreachable}) catch unreachable,
            8 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '^', '>' }) catch unreachable, allocator.dupe(u8, &.{ '^', '>', '^' }) catch unreachable, allocator.dupe(u8, &.{ '>', '^', '^' }) catch unreachable }) catch unreachable,
            9 => {
                const fourToNine = shortestSequencesToMoveNumericFromAToB(4, 9, allocator);
                const fourBasedMoves = prependSequencesWith(fourToNine, '^', allocator);

                const twoToNine = shortestSequencesToMoveNumericFromAToB(2, 9, allocator);
                const twoBasedMoves = prependSequencesWith(twoToNine, '>', allocator);
                return joinSlices(fourBasedMoves, twoBasedMoves, allocator);
            },
            10 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '>', '>', 'v' }) catch unreachable, allocator.dupe(u8, &.{ '>', 'v', '>' }) catch unreachable }) catch unreachable,
            else => unreachable,
        },
        2 => switch (b) {
            3 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'>'}) catch unreachable}) catch unreachable,
            4 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '<' }) catch unreachable, allocator.dupe(u8, &.{ '<', '^' }) catch unreachable }) catch unreachable,
            5 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'^'}) catch unreachable}) catch unreachable,
            6 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '>' }) catch unreachable, allocator.dupe(u8, &.{ '>', '^' }) catch unreachable }) catch unreachable,
            7 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '^', '<' }) catch unreachable, allocator.dupe(u8, &.{ '^', '<', '^' }) catch unreachable, allocator.dupe(u8, &.{ '<', '^', '^' }) catch unreachable }) catch unreachable,
            8 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{ '^', '^' }) catch unreachable}) catch unreachable,
            9 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '^', '>' }) catch unreachable, allocator.dupe(u8, &.{ '^', '>', '^' }) catch unreachable, allocator.dupe(u8, &.{ '>', '^', '^' }) catch unreachable }) catch unreachable,
            10 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '>', 'v' }) catch unreachable, allocator.dupe(u8, &.{ 'v', '>' }) catch unreachable }) catch unreachable,
            else => unreachable,
        },
        3 => switch (b) {
            4 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '<', '<' }) catch unreachable, allocator.dupe(u8, &.{ '<', '^', '<' }) catch unreachable, allocator.dupe(u8, &.{ '<', '<', '^' }) catch unreachable }) catch unreachable,
            5 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '<' }) catch unreachable, allocator.dupe(u8, &.{ '<', '^' }) catch unreachable }) catch unreachable,
            6 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'^'}) catch unreachable}) catch unreachable,
            7 => {
                const sixToSeven = shortestSequencesToMoveNumericFromAToB(6, 7, allocator);
                const sixBasedMoves = prependSequencesWith(sixToSeven, '^', allocator);

                const twoToSeven = shortestSequencesToMoveNumericFromAToB(2, 7, allocator);
                const twoBasedMoves = prependSequencesWith(twoToSeven, '<', allocator);
                return joinSlices(sixBasedMoves, twoBasedMoves, allocator);
            },
            8 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '^', '<' }) catch unreachable, allocator.dupe(u8, &.{ '^', '<', '^' }) catch unreachable, allocator.dupe(u8, &.{ '<', '^', '^' }) catch unreachable }) catch unreachable,
            9 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{ '^', '^' }) catch unreachable}) catch unreachable,
            10 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'v'}) catch unreachable}) catch unreachable,
            else => unreachable,
        },
        4 => switch (b) {
            5 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'>'}) catch unreachable}) catch unreachable,
            6 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{ '>', '>' }) catch unreachable}) catch unreachable,
            7 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'^'}) catch unreachable}) catch unreachable,
            8 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '>', '^' }) catch unreachable, allocator.dupe(u8, &.{ '^', '>' }) catch unreachable }) catch unreachable,
            9 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '>', '>' }) catch unreachable, allocator.dupe(u8, &.{ '>', '^', '>' }) catch unreachable, allocator.dupe(u8, &.{ '^', '>', '>' }) catch unreachable }) catch unreachable,
            10 => {
                const fiveToA = shortestSequencesToMoveNumericFromAToB(5, 10, allocator);
                const fiveBasedMoves = prependSequencesWith(fiveToA, '>', allocator);

                const oneToA = shortestSequencesToMoveNumericFromAToB(1, 10, allocator);
                const oneBasedMoves = prependSequencesWith(oneToA, 'v', allocator);
                return joinSlices(fiveBasedMoves, oneBasedMoves, allocator);
            },
            else => unreachable,
        },
        5 => switch (b) {
            6 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'>'}) catch unreachable}) catch unreachable,
            7 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '<' }) catch unreachable, allocator.dupe(u8, &.{ '<', '^' }) catch unreachable }) catch unreachable,
            8 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'^'}) catch unreachable}) catch unreachable,
            9 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{ '^', '>' }) catch unreachable}) catch unreachable,
            10 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ 'v', 'v', '>' }) catch unreachable, allocator.dupe(u8, &.{ 'v', '>', 'v' }) catch unreachable, allocator.dupe(u8, &.{ '>', 'v', 'v' }) catch unreachable }) catch unreachable,
            else => unreachable,
        },
        6 => switch (b) {
            7 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '<', '<' }) catch unreachable, allocator.dupe(u8, &.{ '<', '^', '<' }) catch unreachable, allocator.dupe(u8, &.{ '^', '<', '<' }) catch unreachable }) catch unreachable,
            8 => allocator.dupe([]u8, &.{ allocator.dupe(u8, &.{ '^', '<' }) catch unreachable, allocator.dupe(u8, &.{ '<', '^' }) catch unreachable }) catch unreachable,
            9 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'^'}) catch unreachable}) catch unreachable,
            10 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{ 'v', 'v' }) catch unreachable}) catch unreachable,
            else => unreachable,
        },
        7 => switch (b) {
            8 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'>'}) catch unreachable}) catch unreachable,
            9 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{ '>', '>' }) catch unreachable}) catch unreachable,
            10 => {
                const eightToA = shortestSequencesToMoveNumericFromAToB(8, 10, allocator);
                const eightBasedMoves = prependSequencesWith(eightToA, '>', allocator);

                const fourToA = shortestSequencesToMoveNumericFromAToB(4, 10, allocator);
                const fourBasedMoves = prependSequencesWith(fourToA, 'v', allocator);
                return joinSlices(eightBasedMoves, fourBasedMoves, allocator);
            },
            else => unreachable,
        },
        8 => switch (b) {
            9 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{'>'}) catch unreachable}) catch unreachable,
            10 => {
                const nineToA = shortestSequencesToMoveNumericFromAToB(9, 10, allocator);
                const nineBasedMoves = prependSequencesWith(nineToA, '>', allocator);

                const fiveToA = shortestSequencesToMoveNumericFromAToB(5, 10, allocator);
                const fiveBasedMoves = prependSequencesWith(fiveToA, 'v', allocator);
                return joinSlices(nineBasedMoves, fiveBasedMoves, allocator);
            },
            else => unreachable,
        },
        9 => switch (b) {
            10 => allocator.dupe([]u8, &.{allocator.dupe(u8, &.{ 'v', 'v', 'v' }) catch unreachable}) catch unreachable,
            else => unreachable,
        },
        else => unreachable,
    };
}

// Need to make these via a separate function rather than using the `&.{&.{...}}` syntax, because the latter doesn't use
// an allocator and so attempts to `free` them will give bus errors.
// This language is _really_ awkward sometimes...
fn makeSliceOfSlices(strings: []const []const u8, allocator: std.mem.Allocator) [][]u8 {
    var op = std.ArrayList([]u8).init(allocator);
    for (strings) |string| {
        var slice = allocator.alloc(u8, string.len) catch unreachable;
        for (string, 0..) |c, i| {
            slice[i] = c;
        }
        op.append(slice) catch unreachable;
    }
    return op.toOwnedSlice() catch unreachable;
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

fn joinSlices(a: []const []const u8, b: []const []const u8, allocator: std.mem.Allocator) []const []const u8 {
    var op = std.ArrayList([]const u8).init(allocator);
    for (a) |seq| {
        op.append(seq) catch unreachable;
    }
    for (b) |seq| {
        op.append(seq) catch unreachable;
    }
    allocator.free(a);
    allocator.free(b);
    return op.toOwnedSlice() catch unreachable;
}

fn prependSequencesWith(seqs: []const []const u8, prefix: u8, allocator: std.mem.Allocator) [][]u8 {
    const resp = allocator.alloc([]u8, seqs.len) catch unreachable;
    for (seqs, 0..) |seq, i| {
        var new_seq = allocator.alloc(u8, seq.len + 1) catch unreachable;
        new_seq[0] = prefix;
        for (seq, 0..) |c, j| {
            new_seq[j + 1] = c;
        }
        resp[i] = new_seq;
        allocator.free(seq);
    }
    allocator.free(seqs);
    return resp;
}

fn appendSequencesWith(seqs: []const []const u8, suffix: u8, allocator: std.mem.Allocator) [][]u8 {
    const resp = allocator.alloc([]u8, seqs.len) catch unreachable;
    for (seqs, 0..) |seq, i| {
        var new_seq = allocator.alloc(u8, seq.len + 1) catch unreachable;
        for (seq, 0..) |c, j| {
            new_seq[j] = c;
        }
        new_seq[seq.len] = suffix;
        resp[i] = new_seq;
        allocator.free(seq);
    }
    allocator.free(seqs);
    return resp;
}

const NumericRobotError = error{ OutOfBoundsError, GapError };

// To test, implement an actual robot!
const NumericRobot = struct {
    pos: Point,
    pub fn move(self: *NumericRobot, m: u8) void {
        switch (m) {
            '^' => self.pos.y += 1,
            '>' => self.pos.x += 1,
            'v' => self.pos.y -= 1,
            '<' => self.pos.x -= 1,
            else => {
                //std.debug.print("Encountered unparsable move {}\n", .{m});
                unreachable;
            },
        }
    }

    pub fn process(self: *NumericRobot, moves: []const u8) NumericRobotError!void {
        for (moves) |m| {
            self.move(m);
            if (self.pos.x == 0 and self.pos.y == 0) {
                return NumericRobotError.GapError;
            }
            // No need to check for <0 as that'll be a language error anyway
            if (self.pos.x > 2 or self.pos.y > 3) {
                return NumericRobotError.OutOfBoundsError;
            }
        }
        return {};
    }

    pub fn pointForNumber(number: u8) Point {
        return switch (number) {
            0 => Point{ .x = 1, .y = 0 },
            1...9 => {
                const x = (number - 1) % 3;
                const y = @divFloor(number - 1, 3) + 1;
                return Point{ .x = x, .y = y };
            },
            10 => Point{ .x = 2, .y = 0 },
            else => unreachable,
        };
    }

    pub fn numberForPoint(point: Point) u8 {
        if (point.y > 0 and point.y < 4 and point.x >= 0 and point.x < 3) {
            return 3 * (point.y - 1) + point.x + 1;
        }
        if (point.y == 0) {
            switch (point.x) {
                1 => return 0,
                2 => return 10,
                else => unreachable,
            }
        }
        unreachable;
    }
};

const DirectionalRobotError = error{ OutOfBoundsError, GapError };

// TODO - a lot of this could probably be extracted from here and NumericRobot (I don't know if Zig has subclassing)
const DirectionalRobot = struct {
    pos: Point,
    pub fn move(self: *DirectionalRobot, m: u8) void {
        switch (m) {
            '^' => self.pos.y += 1,
            '>' => self.pos.x += 1,
            'v' => self.pos.y -= 1,
            '<' => self.pos.x -= 1,
            else => {
                //std.debug.print("Dencountered unparsable move {}\n", .{m});
                unreachable;
            },
        }
    }

    pub fn process(self: *DirectionalRobot, moves: []const u8) DirectionalRobotError!void {
        for (moves) |m| {
            self.move(m);
            if (self.pos.x == 0 and self.pos.y == 1) {
                return DirectionalRobotError.GapError;
            }
            if (self.pos.x > 2 or self.pos.y > 1) {
                return DirectionalRobotError.OutOfBoundsError;
            }
        }
        return {};
    }

    pub fn pointForSymbol(symbol: u8) Point {
        return switch (symbol) {
            '^' => Point{ .x = 1, .y = 1 },
            '<' => Point{ .x = 0, .y = 0 },
            'v' => Point{ .x = 1, .y = 0 },
            '>' => Point{ .x = 2, .y = 0 },
            'A' => Point{ .x = 2, .y = 1 },
            else => unreachable,
        };
    }

    pub fn symbolForPoint(point: Point) u8 {
        return switch (point.x) {
            0 => {
                if (point.y == 0) {
                    return '<';
                } else {
                    unreachable;
                }
            },
            1 => switch (point.y) {
                0 => 'v',
                1 => '^',
                else => unreachable,
            },
            2 => switch (point.y) {
                0 => '>',
                1 => 'A',
                else => unreachable,
            },
            else => unreachable,
        };
    }
};

fn makeZeroToOneSequenceDirectly(allocator: std.mem.Allocator) [][]const u8 {
    var op = std.ArrayList([]const u8).init(allocator);
    op.append("hello") catch unreachable;
    return op.toOwnedSlice() catch unreachable;
}

fn printDirectionSeqAsDirections(_: []const u8) void {
    // for (seq) |c| {
    //     //std.debug.print("{c}", .{c});
    // }
}

test "Basic Movement" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var seqs = shortestSequencesToMoveNumericFromAToB(0, 7, allocator);
    for (seqs) |seq| {
        var robot = NumericRobot{ .pos = Point{ .x = 1, .y = 0 } };
        robot.process(seq) catch unreachable;
        try expect(std.meta.eql(robot.pos, Point{ .x = 0, .y = 3 }));
        allocator.free(seq); // TODO - I could probably do some fancy shenanigans with `errdefer` here (and elsewhere)
    }
    allocator.free(seqs); // I don't know why this is necessary!? I'm re-allocating to it on the next line :shrug:

    seqs = shortestSequencesToMoveNumericFromAToB(7, 0, allocator);
    for (seqs) |seq| {
        var robot = NumericRobot{ .pos = Point{ .x = 0, .y = 3 } };
        robot.process(seq) catch unreachable;
        try expect(std.meta.eql(robot.pos, Point{ .x = 1, .y = 0 }));
        allocator.free(seq);
    }
    allocator.free(seqs);

    seqs = shortestSequencesToMoveNumericFromAToB(0, 1, allocator);
    for (seqs) |seq| {
        var robot = NumericRobot{ .pos = Point{ .x = 1, .y = 0 } };
        robot.process(seq) catch unreachable;
        const expected_point = Point{ .x = 0, .y = 1 };
        try expect(std.meta.eql(robot.pos, expected_point));
        allocator.free(seq);
    }
    allocator.free(seqs);
}

test "Exhaustive Movement test" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    for (0..11) |i| {
        for (0..11) |j| {
            const i_as_u8: u8 = @intCast(i);
            const j_as_u8: u8 = @intCast(j);
            const seqs = shortestSequencesToMoveNumericFromAToB(i_as_u8, j_as_u8, allocator);
            for (seqs) |seq| {
                var robot = NumericRobot{ .pos = NumericRobot.pointForNumber(i_as_u8) };
                robot.process(seq) catch unreachable;
                try expect(std.meta.eql(robot.pos, NumericRobot.pointForNumber(j_as_u8)));
                allocator.free(seq);
            }
            allocator.free(seqs);
        }
    }
}

test "Shortest sequences for first level of indirection" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const sequences = shortestDirectionalPushesToEnterNumericSequence("029A", allocator);
    defer allocator.free(sequences);
    // for readable output, uncomment the lines below
    // ---------
    // for (sequences) |seq| {
    //     printDirectionSeqAsDirections(seq);
    //     //std.debug.print("\n", .{});
    //     // Not sure why we don't need to `allocator.free(seq)` here :shrug:
    // }
    // ---------
    const targetSequence = allocator.dupe(u8, &.{ '<', 'A', '^', 'A', '>', '^', '^', 'A', 'v', 'v', 'v', 'A' }) catch unreachable;
    defer allocator.free(targetSequence);
    var foundTargetSequence = false;
    for (sequences) |seq| {
        if (std.mem.eql(u8, seq, targetSequence)) {
            foundTargetSequence = true;
            break;
        } else {
            //std.debug.print("Found the following sequence: ", .{});
            printDirectionSeqAsDirections(seq);
            //std.debug.print("\n", .{});
        }
    }
    try expect(foundTargetSequence);
}

test "Basic Navigation of Directional Keypad" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var robot = DirectionalRobot{ .pos = Point{ .x = 2, .y = 1 } };
    const sequencesToLeft = shortestSequencesToMoveDirectionalFromAToB('A', '<', allocator);
    try expect(sequencesToLeft.len > 0);
    robot.process(sequencesToLeft[0]) catch unreachable;
    for (sequencesToLeft) |seq| {
        allocator.free(seq);
    }
    allocator.free(sequencesToLeft);
    try expect(std.meta.eql(robot.pos, Point{ .x = 0, .y = 0 }));

    const sequencesToUp = shortestSequencesToMoveDirectionalFromAToB('<', '^', allocator);
    try expect(sequencesToUp.len > 0);
    robot.process(sequencesToUp[0]) catch unreachable;
    for (sequencesToUp) |seq| {
        allocator.free(seq);
    }
    allocator.free(sequencesToUp);
    try expect(std.meta.eql(robot.pos, Point{ .x = 1, .y = 1 }));

    const sequencesToRight = shortestSequencesToMoveDirectionalFromAToB('^', '>', allocator);
    try expect(sequencesToRight.len > 0);
    robot.process(sequencesToRight[0]) catch unreachable;
    for (sequencesToRight) |seq| {
        allocator.free(seq);
    }
    allocator.free(sequencesToRight);
    try expect(std.meta.eql(robot.pos, Point{ .x = 2, .y = 0 }));
}

test "Direct second-level operation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const second_level_sequences = shortestDirectionalPushesToEnterDirectionalSequence("<A^A>^^AvvvA", allocator);
    //std.debug.print("Found {} second-level sequences\n", .{second_level_sequences.len});

    var shortest_so_far: usize = std.math.maxInt(usize);
    var shortest_sequences = std.ArrayList([]const u8).init(allocator);

    for (second_level_sequences) |second_level_sequence| {
        //std.debug.print("Processing this second_level sequence: {any}\n", .{second_level_sequence});
        const len = second_level_sequence.len;
        if (len > shortest_so_far) {
            continue;
        }
        if (len == shortest_so_far) {
            shortest_sequences.append(second_level_sequence) catch unreachable;
        }
        if (len < shortest_so_far) {
            shortest_so_far = len;
            shortest_sequences.clearRetainingCapacity();
            shortest_sequences.append(second_level_sequence) catch unreachable;
        }
        // allocator.free(second_level_sequence); -- again, don't know why this isn't necessary
    }
    allocator.free(second_level_sequences);

    var foundSequence = false;
    //std.debug.print("We found {} shortest sequences\n", .{shortest_sequences.items.len});
    for (shortest_sequences.items) |shortest| {
        //std.debug.print("Found this shortest-sequence:", .{});
        printDirectionSeqAsDirections(shortest);
        //std.debug.print("\n", .{});
        if (std.mem.eql(u8, shortest, "v<<A>>^A<A>AvA<^AA>A<vAAA>^A")) {
            foundSequence = true;
            // Apparently it's not necessary to...
            // allocator.free(shortest);
            // ... so we can just...
            break;
        }
    }
    shortest_sequences.deinit();
    try expect(foundSequence);
}

test "One Pass Through" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const sequences = shortestDirectionalPushesToEnterNumericSequence("029A", allocator);
    defer allocator.free(sequences);
    // I have no idea why this (and the other commented-out example) free isn't required :shrug:
    // defer {
    //     for (sequences) |seq| {
    //         allocator.free(seq);
    //     }
    // }
    //std.debug.print("Found {} first-level sequences\n", .{sequences.len});
    var second_level_sequences_list = std.ArrayList([]const u8).init(allocator);
    for (sequences) |seq| {
        const seconds = shortestDirectionalPushesToEnterDirectionalSequence(seq, allocator);
        for (seconds) |sec| {
            second_level_sequences_list.append(sec) catch unreachable;
            // allocator.free(sec);
        }
        allocator.free(seconds);
    }

    const second_level_sequences = second_level_sequences_list.toOwnedSlice() catch unreachable;
    defer allocator.free(second_level_sequences);
    // defer {
    //     for (second_level_sequences) |sls| {
    //         allocator.free(sls);
    //     }
    // }
    //std.debug.print("Found {} second-level sequences\n", .{second_level_sequences_list.items.len});

    var shortest_so_far: usize = std.math.maxInt(usize);
    var shortest_sequences = std.ArrayList([]const u8).init(allocator);

    for (second_level_sequences) |second_level_sequence| {
        //std.debug.print("Processing this second_level sequence: {any}\n", .{second_level_sequence});
        const len = second_level_sequence.len;
        if (len > shortest_so_far) {
            continue;
        }
        if (len == shortest_so_far) {
            shortest_sequences.append(second_level_sequence) catch unreachable;
        }
        if (len < shortest_so_far) {
            shortest_so_far = len;
            shortest_sequences.clearRetainingCapacity();
            shortest_sequences.append(second_level_sequence) catch unreachable;
        }
    }

    var foundSequence = false;
    //std.debug.print("We found {} shortest sequences\n", .{shortest_sequences.items.len});
    for (shortest_sequences.items) |shortest| {
        //std.debug.print("Found this shortest-sequence:", .{});
        printDirectionSeqAsDirections(shortest);
        //std.debug.print("\n", .{});
        if (std.mem.eql(u8, shortest, "v<<A>>^A<A>AvA<^AA>A<vAAA>^A")) {
            foundSequence = true;
            // Apparently it's not necessary to...
            // allocator.free(shortest);
            // ... so we can just...
            break;
        }
    }
    shortest_sequences.deinit();
    try expect(foundSequence);
}

test "Min Length of 3-times loop" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const min_length = findLengthOfShortestResultOfLoopingNTimes("029A", 3, allocator);
    try expect(min_length == 69);
}
