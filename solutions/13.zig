const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");
const expect = std.testing.expect;

pub fn main() !void {
    const response = try part_two(false);
    print("{}\n", .{response});
}

const CaseError = error{ ArithmeticError, InsolubleError, ZeroDivisionError };

const Solution = struct { a: u32, b: u32 };
const SolutionTakeTwo = struct { a: u64, b: u64 };

const Case = struct {
    ax: u32,
    ay: u32,
    bx: u32,
    by: u32,
    prizex: u32,
    prizey: u32,
    pub fn from_lines(a_line: []const u8, b_line: []const u8, prize_line: []const u8) anyerror!Case {
        // Looks like there are no regexes in Zig :shrug:
        print("DEBUG - parsing a_line: {s}\n", .{a_line});
        const start_of_ax: usize = 12;
        const end_of_ax: usize = std.mem.indexOf(u8, a_line, ",").?;
        const start_of_ay: usize = std.mem.indexOf(u8, a_line, "Y").? + 2;
        const ax = try std.fmt.parseInt(u32, a_line[start_of_ax..end_of_ax], 10);
        const ay = try std.fmt.parseInt(u32, a_line[start_of_ay..a_line.len], 10);

        const start_of_bx: usize = 12;
        const end_of_bx: usize = std.mem.indexOf(u8, b_line, ",").?;
        const start_of_by: usize = std.mem.indexOf(u8, b_line, "Y").? + 2;
        const bx = try std.fmt.parseInt(u32, b_line[start_of_bx..end_of_bx], 10);
        const by = try std.fmt.parseInt(u32, b_line[start_of_by..b_line.len], 10);

        const start_of_prizex: usize = 9;
        const end_of_prizex: usize = std.mem.indexOf(u8, prize_line, ",").?;
        const start_of_prizey: usize = std.mem.indexOf(u8, prize_line, "Y").? + 2;
        const prizex = try std.fmt.parseInt(u32, prize_line[start_of_prizex..end_of_prizex], 10);
        const prizey = try std.fmt.parseInt(u32, prize_line[start_of_prizey..prize_line.len], 10);

        return Case{ .ax = ax, .ay = ay, .bx = bx, .by = by, .prizex = prizex, .prizey = prizey };
    }

    pub fn solve(self: *const Case) CaseError!Solution {
        // Logic:
        // * Increment b (since b is cheaper than a) until x and y values are >= targets
        //   * If x and y values are equal to the targets, _and_ b <= 100, then we're done - return
        // * Repeatedly:
        //    * Increment a, then decrement b until _at least one_ x or y value is <= targets
        //    * If both x and y are equal to targets, and b <= 100, then return
        //    * Else:
        //      * Increment b until both x and y are >= targets
        //      * If a is 100, the Case is insoluble. Else, loop (so a will get incremented as the loop starts again)

        var a: u32 = 0;
        var b: u32 = 0;
        b = @max(self.prizex / self.bx, self.prizey / self.by);
        // There's probably a way to do this in a single pass, but :shrug:
        if (self.bx * b < self.prizex or self.by * b < self.prizey) {
            b += 1;
        }
        // This _shouldn't_ be necessary, but I don't trust myself with Zig arithmetic yet!
        if (self.bx * b < self.prizex or self.by * b < self.prizey) {
            print("Arithmetic error while operating on {}\n", .{self});
            return CaseError.ArithmeticError;
        }

        if (self.bx * b == self.prizex and self.by * b == self.prizey and b <= 100) {
            return .{ .a = 0, .b = b };
        }

        while (true) {
            // Could _probably do this as part of the `while` loop definition, but it makes more sense to my brain
            // as the first statement like this.
            a += 1;
            while (self.ax * a + self.bx * b > self.prizex or self.ay * a + self.by * b > self.prizey) : (b -= 1) {
                if (b == 0) {
                    return CaseError.InsolubleError;
                }
            }
            if (self.ax * a + self.bx * b == self.prizex and self.ay * a + self.by * b == self.prizey and b <= 100) {
                return .{ .a = a, .b = b };
            } else {
                while (self.ax * a + self.bx * b < self.prizex and self.ay * a + self.by * b < self.prizey) : (b += 1) {}
                if (a == 100) {
                    return CaseError.InsolubleError;
                } // else - continue loop, increment a, keep trying
            }
        }
    }
};

const CaseTakeTwo = struct {
    ax: u64,
    ay: u64,
    bx: u64,
    by: u64,
    prizex: u64,
    prizey: u64,
    pub fn from_lines(a_line: []const u8, b_line: []const u8, prize_line: []const u8) anyerror!CaseTakeTwo {
        // Looks like there are no regexes in Zig :shrug:
        print("DEBUG - parsing a_line: {s}\n", .{a_line});
        const start_of_ax: usize = 12;
        const end_of_ax: usize = std.mem.indexOf(u8, a_line, ",").?;
        const start_of_ay: usize = std.mem.indexOf(u8, a_line, "Y").? + 2;
        const ax = try std.fmt.parseInt(u64, a_line[start_of_ax..end_of_ax], 10);
        const ay = try std.fmt.parseInt(u64, a_line[start_of_ay..a_line.len], 10);

        const start_of_bx: usize = 12;
        const end_of_bx: usize = std.mem.indexOf(u8, b_line, ",").?;
        const start_of_by: usize = std.mem.indexOf(u8, b_line, "Y").? + 2;
        const bx = try std.fmt.parseInt(u64, b_line[start_of_bx..end_of_bx], 10);
        const by = try std.fmt.parseInt(u64, b_line[start_of_by..b_line.len], 10);

        const start_of_prizex: usize = 9;
        const end_of_prizex: usize = std.mem.indexOf(u8, prize_line, ",").?;
        const start_of_prizey: usize = std.mem.indexOf(u8, prize_line, "Y").? + 2;
        const prizex = try std.fmt.parseInt(u64, prize_line[start_of_prizex..end_of_prizex], 10) + 10000000000000;
        const prizey = try std.fmt.parseInt(u64, prize_line[start_of_prizey..prize_line.len], 10) + 10000000000000;

        return CaseTakeTwo{ .ax = ax, .ay = ay, .bx = bx, .by = by, .prizex = prizex, .prizey = prizey };
    }

    pub fn solve(self: *const CaseTakeTwo) CaseError!SolutionTakeTwo {
        // The iterative approach doesn't work here :P take the exact numerical approach.
        // A little algebraic rearrangement gives us:
        //
        // ```
        // b ( x_1 y_2 - x_2 y_1) = x_1 t_y - y_1 t_x
        // ```
        //
        // So, if the LHS factor does not divide the RHS factor, we know the case is insoluble;
        // and if they _do_ divide, this gives us an equation for b.
        // (Question - there could be cases where there are multiple solutions, what would that look like? Cross that
        // bridge when we come to it.)

        // Because heaven forbid we have a filthy <gasp> *NEGATIVE NUMBER* in our data.
        // Won't somebody please think of the children!
        if ((self.ax * self.by) >= (self.bx * self.ay)) {
            const lhs = (self.ax * self.by) - (self.bx * self.ay);
            if (lhs == 0) {
                print("SOMETHING WEIRD HAPPENED - zero-division in case {}\n", .{self});
                return CaseError.ZeroDivisionError;
            }
            if (self.ax * self.prizey <= self.ay * self.prizex) {
                // i.e. lhs and rhs would have different signs
                return CaseError.InsolubleError;
            }
            const rhs = (self.ax * self.prizey - self.ay * self.prizex);
            if (rhs % lhs != 0) {
                return CaseError.InsolubleError;
            }
            // We know that lhs divides rhs exactly, so...
            const b = @divExact(rhs, lhs);
            print("DEBUG - b is {}\n", .{b});

            const a_calc_numerator = self.prizex - (b * self.bx);
            const a_calc_denominator = self.ax;
            if (a_calc_numerator % a_calc_denominator != 0) {
                return CaseError.InsolubleError;
            }
            const a = @divExact(a_calc_numerator, a_calc_denominator);
            return SolutionTakeTwo{ .a = a, .b = b };
        } else {
            const lhs = (self.bx * self.ay) - (self.ax * self.by);
            if (lhs == 0) {
                print("SOMETHING WEIRD HAPPENED - zero-division in case {}\n", .{self});
                return CaseError.ZeroDivisionError;
            }
            if (self.ay * self.prizex <= self.ax * self.prizey) {
                // i.e. lhs and rhs would have different signs
                return CaseError.InsolubleError;
            }
            const rhs = (self.ay * self.prizex - self.ax * self.prizey);
            if (rhs % lhs != 0) {
                return CaseError.InsolubleError;
            }
            // We know that lhs divides rhs exactly, so...
            const b = @divExact(rhs, lhs);
            print("DEBUG - b is {}\n", .{b});

            const a_calc_numerator = self.prizex - (b * self.bx);
            const a_calc_denominator = self.ax;
            if (a_calc_numerator % a_calc_denominator != 0) {
                return CaseError.InsolubleError;
            }
            const a = @divExact(a_calc_numerator, a_calc_denominator);
            return SolutionTakeTwo{ .a = a, .b = b };
        }
    }
};

fn part_one(is_test_case: bool) anyerror!u128 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("13", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    var it = std.mem.splitScalar(u8, data, '\n');
    var cases = std.ArrayList(Case).init(allocator);
    defer cases.deinit();
    while (true) {
        const a_line = it.next().?;
        const b_line = it.next().?;
        const prize_line = it.next().?;
        _ = it.next();

        try cases.append(try Case.from_lines(a_line, b_line, prize_line));

        if (it.peek() == null) {
            break;
        }
    }
    var total: u32 = 0;
    for (cases.items) |case| {
        print("Solution to case {}", .{case});
        if (case.solve()) |solution| {
            print(" is {}\n", .{solution});
            total += solution.a * 3 + solution.b;
        } else |_| {
            print(" is impossible\n", .{});
        }
    }
    return total;
}

fn part_two(is_test_case: bool) anyerror!u128 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("13", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    var it = std.mem.splitScalar(u8, data, '\n');
    var cases = std.ArrayList(CaseTakeTwo).init(allocator);
    defer cases.deinit();
    while (true) {
        const a_line = it.next().?;
        const b_line = it.next().?;
        const prize_line = it.next().?;
        _ = it.next();

        try cases.append(try CaseTakeTwo.from_lines(a_line, b_line, prize_line));

        if (it.peek() == null) {
            break;
        }
    }
    var total: u64 = 0;
    for (cases.items) |case| {
        print("Solution to case {}", .{case});
        if (case.solve()) |solution| {
            print(" is {}\n", .{solution});
            total += solution.a * 3 + solution.b;
        } else |_| {
            print(" is impossible\n", .{});
        }
    }
    return total;
}

test "part_one" {
    const part_one_response = try part_one(true);
    print("DEBUG - part_one_response is {}\n", .{part_one_response});
    try expect(part_one_response == 480);
}
