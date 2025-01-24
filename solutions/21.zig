const std = @import("std");
const util = @import("util.zig");
const Point = util.Point;
const expect = std.testing.expect;

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
    // God bless https://stackoverflow.com/a/77248553 for showing me how to initialize a slice of slices!
    return switch (a) {
        0 => switch (b) {
            1 => &.{&.{ '^', '<' }},
            2 => &.{&.{'^'}},
            3 => &.{ &.{ '^', '>' }, &.{ '>', '^' } },
            4 => &.{ &.{ '^', '^', '<' }, &.{ '^', '<', '^' } },
            5 => &.{&.{ '^', '^' }},
            6 => &.{ &.{ '^', '^', '>' }, &.{ '^', '>', '^' }, &.{ '>', '^', '^' } },
            7 => {
                const twoToSeven = shortestSequencesToMoveNumericFromAToB(2, 7, allocator);
                return prependSequencesWith(twoToSeven, '^', allocator);
            },
            8 => &.{&.{ '^', '^', '^' }},
            9 => &.{ &.{ '^', '^', '^', '>' }, &.{ '^', '^', '>', '^' }, &.{ '^', '>', '^', '^' }, &.{ '>', '^', '^', '^' } },
            10 => &.{&.{'>'}},
            else => unreachable,
        },
        1 => switch (b) {
            0 => &.{&.{ '>', 'V' }},
            2 => &.{&.{'>'}},
            3 => &.{&.{ '>', '>' }},
            4 => &.{&.{'^'}},
            5 => &.{ &.{ '^', '>' }, &.{ '>', '^' } },
            6 => &.{ &.{ '^', '>', '>' }, &.{ '>', '^', '>' }, &.{ '>', '>', '^' } },
            7 => &.{&.{ '^', '^' }},
            8 => &.{ &.{ '^', '^', '>' }, &.{ '^', '>', '^' }, &.{ '>', '^', '^' } },
            9 => {
                const fourToNine = shortestSequencesToMoveNumericFromAToB(4, 9, allocator);
                const fourBasedMoves = prependSequencesWith(fourToNine, '^', allocator);

                const twoToNine = shortestSequencesToMoveNumericFromAToB(2, 9, allocator);
                const twoBasedMoves = prependSequencesWith(twoToNine, '>', allocator);
                return joinSlices(fourBasedMoves, twoBasedMoves, allocator);
            },
            10 => &.{ &.{ '>', '>', 'V' }, &.{ '>', 'V', '>' } },
            else => unreachable,
        },
        2 => switch (b) {
            3 => &.{&.{'>'}},
            4 => &.{ &.{ '^', '<' }, &.{ '<', '^' } },
            5 => &.{&.{'^'}},
            6 => &.{ &.{ '^', '>' }, &.{ '>', '^' } },
            7 => &.{ &.{ '^', '^', '<' }, &.{ '^', '<', '^' }, &.{ '<', '^', '^' } },
            8 => &.{&.{ '^', '^' }},
            9 => &.{ &.{ '^', '^', '>' }, &.{ '^', '>', '^' }, &.{ '>', '^', '^' } },
            10 => &.{ &.{ '>', 'V' }, &.{ 'V', '>' } },
            else => unreachable,
        },
        3 => switch (b) {
            4 => &.{ &.{ '^', '<', '<' }, &.{ '<', '^', '<' }, &.{ '<', '<', '^' } },
            5 => &.{ &.{ '^', '<' }, &.{ '<', '^' } },
            6 => &.{&.{'^'}},
            7 => {
                const sixToSeven = shortestSequencesToMoveNumericFromAToB(6, 7, allocator);
                const sixBasedMoves = prependSequencesWith(sixToSeven, '^', allocator);

                const twoToSeven = shortestSequencesToMoveNumericFromAToB(2, 7, allocator);
                const twoBasedMoves = prependSequencesWith(twoToSeven, '<', allocator);
                return joinSlices(sixBasedMoves, twoBasedMoves, allocator);
            },
            8 => &.{ &.{ '^', '^', '<' }, &.{ '^', '<', '^' }, &.{ '<', '^', '^' } },
            9 => &.{&.{ '^', '^' }},
            10 => &.{&.{'V'}},
            else => unreachable,
        },
        8 => switch (b) {
            // 10 => &.{&.{'V'}},
            10 => &.{ &.{ 'V', 'V', 'V', '>' }, &.{ 'V', 'V', '>', 'V' }, &.{ 'V', '>', 'V', 'V' }, &.{ '>', 'V', 'V', 'V' } },
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
            '^' => op.append('V') catch unreachable,
            '<' => op.append('>') catch unreachable,
            'V' => op.append('^') catch unreachable,
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
    }
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
            'V' => self.pos.y -= 1,
            '<' => self.pos.x -= 1,
            else => unreachable,
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
};

test "Basic Movement" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const seqs = shortestSequencesToMoveNumericFromAToB(0, 7, allocator);
    for (seqs) |seq| {
        var robot = NumericRobot{ .pos = Point{ .x = 1, .y = 0 } };
        robot.process(seq) catch unreachable;
        try expect(std.meta.eql(robot.pos, Point{ .x = 0, .y = 3 }));
        allocator.free(seq); // TODO - I could probably do some fancy shenanigans with `errdefer` here (and elsewhere)
    }
    allocator.free(seqs);

    // I don't know why, but reusing `seqs` leads to Memory Leaks, even when (AFAICT) everything is freed.
    const new_seqs = shortestSequencesToMoveNumericFromAToB(7, 0, allocator);
    for (new_seqs) |seq| {
        var robot = NumericRobot{ .pos = Point{ .x = 0, .y = 3 } };
        robot.process(seq) catch unreachable;
        try expect(std.meta.eql(robot.pos, Point{ .x = 1, .y = 0 }));
        allocator.free(seq);
    }
    allocator.free(new_seqs);

    const newer_seqs = shortestSequencesToMoveNumericFromAToB(0, 1, allocator);
    for (newer_seqs) |seq| {
        // var robot = NumericRobot{ .pos = Point{ .x = 2, .y = 0 } };
        // robot.process(seq) catch unreachable;
        // try expect(std.meta.eql(robot.pos, Point{ .x = 1, .y = 3 }));
        allocator.free(seq);
    }
    allocator.free(newer_seqs);
}
