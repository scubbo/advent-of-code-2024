const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");
const expect = std.testing.expect;

// Some memory leaks :shrug:

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    find_quine_value_of_a(&quine_program, allocator);
}

pub fn part_one(is_test_case: bool) ![]u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("17", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    return Computer.run(data, allocator);
}

const ExecutionError = error{InfiniteLoop};

const Computer = struct {
    regA: u64,
    regB: u64,
    regC: u64,
    program: []const u4 = &.{},
    instruction_pointer: u32,
    outputs: std.ArrayList(u64),

    pub fn init(a: u64, b: u64, c: u64, allocator: std.mem.Allocator) Computer {
        return Computer{ .regA = a, .regB = b, .regC = c, .instruction_pointer = 0, .outputs = std.ArrayList(u64).init(allocator) };
    }

    pub fn parse_program(input_line: []const u8, allocator: std.mem.Allocator) ![]u4 {
        const values = input_line[9..];
        var split = std.mem.splitScalar(u8, values, ',');
        var response = std.ArrayList(u4).init(allocator);
        while (split.next()) |v| {
            try response.append(try std.fmt.parseInt(u4, v, 10));
        }
        return try response.toOwnedSlice();
    }

    pub fn deinit(self: *Computer, allocator: std.mem.Allocator) void {
        self.outputs.deinit();
        allocator.free(self.program);
    }

    pub fn run(data: []const u8, allocator: std.mem.Allocator) ![]u64 {
        var lines = std.mem.splitScalar(u8, data, '\n');
        const first_line = lines.next().?;
        const regA = try std.fmt.parseInt(u32, first_line[12..], 10);

        const second_line = lines.next().?;
        const regB = try std.fmt.parseInt(u32, second_line[12..], 10);

        const third_line = lines.next().?;
        const regC = try std.fmt.parseInt(u32, third_line[12..], 10);

        _ = lines.next();
        const program_line = lines.next().?;
        var c = Computer.init(regA, regB, regC, allocator);
        defer c.deinit(allocator);
        const program = try Computer.parse_program(program_line, allocator);
        return c.execute_program(program);
    }

    pub fn execute_program(self: *Computer, program: []const u4) ![]u64 {
        self.program = program;
        var op_count: u32 = 0;
        while (self.instruction_pointer < program.len - 1) : (op_count += 1) {
            // print("DEBUG - a/b/c are {}/{}/{}, pointer {}, values {}-{}\n", .{ self.regA, self.regB, self.regC, self.instruction_pointer, self.program[self.instruction_pointer], self.program[self.instruction_pointer + 1] });
            const operand = program[self.instruction_pointer + 1];
            switch (program[self.instruction_pointer]) {
                0 => self.op_adv(operand),
                1 => self.op_bxl(operand),
                2 => self.op_bst(operand),
                3 => self.op_jnz(operand),
                4 => self.op_bxc(operand),
                5 => self.op_out(operand),
                6 => self.op_bdv(operand),
                7 => self.op_cdv(operand),
                else => unreachable,
            }
            if (op_count > 1000) {
                print("Infinite loop detected for program {any}\n", .{program});
                return ExecutionError.InfiniteLoop;
            }
        }
        return try self.outputs.toOwnedSlice();
    }

    // These need not necessarily be `pub`, but that's helpful for testing.
    pub fn op_adv(self: *Computer, operand: u4) void {
        // print("DEBUG - op_adv with operand {}, ", .{operand});
        self.regA = @divFloor(self.regA, std.math.pow(u64, 2, self.get_combo_value(operand)));
        // print("new value is {}\n", .{self.regA});
        self.instruction_pointer += 2;
    }

    // I wonder if there's a reflection-based way to implement these three functions as parameterizations of a single
    // function?
    pub fn op_bdv(self: *Computer, operand: u4) void {
        // print("DEBUG - op_bdv with operand {}, ", .{operand});
        self.regB = @divFloor(self.regA, std.math.pow(u64, 2, self.get_combo_value(operand)));
        // print("new value is {}\n", .{self.regB});
        self.instruction_pointer += 2;
    }
    pub fn op_cdv(self: *Computer, operand: u4) void {
        // print("DEBUG - op_cdv with operand {}, ", .{operand});
        self.regC = @divFloor(self.regA, std.math.pow(u64, 2, self.get_combo_value(operand)));
        // print("new value is {}\n", .{self.regC});
        self.instruction_pointer += 2;
    }

    pub fn op_bxl(self: *Computer, operand: u4) void {
        // print("DEBUG - op_bxl with operand {}, ", .{operand});
        self.regB = self.regB ^ operand;
        // print("new value is {}\n", .{self.regB});
        self.instruction_pointer += 2;
    }

    pub fn op_bst(self: *Computer, operand: u4) void {
        // print("DEBUG - op_bst with operand {}, ", .{operand});
        self.regB = self.get_combo_value(operand) % 8;
        // print("new value is {}\n", .{self.regB});
        self.instruction_pointer += 2;
    }

    pub fn op_jnz(self: *Computer, operand: u4) void {
        // print("DEBUG - jnz-ing ", .{});
        if (self.regA == 0) {
            // print("but not moving\n", .{});
            self.instruction_pointer += 2;
        } else {
            // print("jumping to {}\n", .{operand});
            self.instruction_pointer = operand;
        }
    }

    pub fn op_bxc(self: *Computer, _: u4) void {
        // print("DEBUG - bxc (no operand), ", .{});
        self.regB = self.regB ^ self.regC;
        // print("new value {}\n", .{self.regB});
        self.instruction_pointer += 2;
    }

    pub fn op_out(self: *Computer, operand: u4) void {
        const new_output = self.get_combo_value(operand) % 8;
        // print("DEBUG - op_out with {}\n", .{new_output});
        self.outputs.append(new_output) catch unreachable;
        self.instruction_pointer += 2;
    }

    fn get_combo_value(self: *Computer, combo_operand: u4) u64 {
        return switch (combo_operand) {
            0...3 => combo_operand, // Do we need to cast this?
            4 => self.regA,
            5 => self.regB,
            6 => self.regC,
            else => {
                print("Unexpected combo_operand {}\n", .{combo_operand});
                unreachable;
            },
        };
    }
};

test "basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var c = Computer.init(128, 40, 98, allocator);
    c.op_adv(3);
    try expect(c.regA == 16);
    c.op_bdv(2);
    try expect(c.regB == 4);
    c.op_cdv(1);
    try expect(c.regC == 8);

    c = Computer.init(128, 40, 98, allocator);
    c.op_bxl(10);
    try expect(c.regB == 34);

    c.op_bst(4);
    try expect(c.regB == 0); // 128 % 8 = 0
    c.op_bst(6);
    try expect(c.regB == 2); // 98 % 8 = 2
    c.op_bst(1);
    try expect(c.regB == 1);
    c.op_bst(2);
    try expect(c.regB == 2);
    c.op_bst(3);
    try expect(c.regB == 3);

    c = Computer.init(128, 40, 98, allocator);
    try expect(c.instruction_pointer == 0);
    c.op_jnz(2);
    try expect(c.instruction_pointer == 2);
    c.regA = 0;
    c.op_jnz(5);
    try expect(c.instruction_pointer == 4); // 2 on from the original 2.
    c.regA = 1;
    c.op_jnz(5);
    try expect(c.instruction_pointer == 5);
}

test "basic_programs" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var c = Computer.init(10, 0, 9, allocator);
    const program1: []const u4 = &.{ 2, 6 };
    const response1 = try c.execute_program(program1);
    allocator.free(response1);
    try expect(c.regB == 1);

    c = Computer.init(10, 0, 9, allocator);
    const program2 = [_]u4{ 5, 0, 5, 1, 5, 4 }; // Apparently, even if a slice is `var`, you can't change its length.
    const response2 = try c.execute_program(&program2);
    try expect(std.mem.eql(u64, response2, &.{ 0, 1, 2 }));
    allocator.free(response2);

    c = Computer.init(2024, 0, 9, allocator);
    const program3 = [_]u4{ 0, 1, 5, 4, 3, 0 };
    const response3 = try c.execute_program(&program3);
    try expect(std.mem.eql(u64, response3, &.{ 4, 2, 5, 6, 7, 7, 7, 7, 3, 1, 0 }));
    try expect(c.regA == 0);
    allocator.free(response3);

    c = Computer.init(2024, 29, 9, allocator);
    const program4 = [_]u4{ 1, 7 };
    const response4 = try c.execute_program(&program4);
    try expect(c.regB == 26);
    allocator.free(response4);

    c = Computer.init(2024, 2024, 43690, allocator);
    const program5 = [_]u4{ 4, 0 };
    const response5 = try c.execute_program(&program5);
    try expect(c.regB == 44354);
    allocator.free(response5);
}

test "part_one" {
    const response = try part_one(true);
    print("DEBUG - part_one response is {any}\n", .{response});
    try expect(std.mem.eql(u64, response, &.{ 4, 6, 3, 5, 6, 3, 5, 2, 1, 0 }));
    // Memory leak here, but we can't free the response without passing an allocator into `part_one` itself 🙃
}

// Everything below here is for the quine investigation
const quine_program = [_]u4{ 2, 4, 1, 1, 7, 5, 0, 3, 4, 3, 1, 6, 5, 5, 3, 0 };
// Observe that the logic of the program is such that:
// * a is (floor)-divided by 8 on each iteration
// * the output at each stage is entirely determined by a (since b and c are)
// * the value of a must be 0 for the last iteration through (in order for the `3,0` jnz command to terminate), and thus
//   * the value of a must be <8 for the penultimate iteration
//
// So, instead of iterating through all possible values (which would take quite a while, as we'd need to examine values
// between 8**15 and 8**16), we can iteratively:
// * find the value of a that:
//   * floor-divs by 8 to give the previously-found value of a
//   * gives output of <the required digit output>
//
// This means that, at every stage of reconstruction (i.e. every digit of the quine_program in reverse), we only need to
// check 8(asterisk...) candidates.
//
// This is complicated by the possibility that there might be multiple such values of a for a given stage, so we need to
// keep track of all possible recursively-built sequences-of-digits, then find the smallest such once we have all
// candidates. So in fact the value in the previous paragraph is 8*n, where n is "the number of candidates there were
// for the previous stage". Still, though - way way fewer than if we were searching them all!

fn find_output_value(a: u64) u4 {
    const b = (a % 8) ^ 1;
    const c = @divFloor(a, std.math.pow(u64, 2, b));
    return @intCast(((b ^ c) ^ 6) % 8);
}

fn find_quine_value_of_a(p: []const u4, allocator: std.mem.Allocator) void {
    var candidates = std.AutoHashMap(u64, bool).init(allocator);
    var next_candidates = std.AutoHashMap(u64, bool).init(allocator);
    candidates.put(0, true) catch unreachable;

    var i: usize = 0;
    while (i < p.len) : (i += 1) {
        const desired_output = p[p.len - (i + 1)];
        print("DEBUG - iteration {}, looking for desired output {}\n", .{ i, desired_output });
        var cand_it = candidates.keyIterator();
        while (cand_it.next()) |cand| {
            const real_cand = cand.*;
            print("DEBUG - candidate is {}\n", .{real_cand});
            print("DEBUG - type of cand is {}\n", .{@TypeOf(real_cand)});
            const lower_bound: u64 = real_cand * @as(u64, 8);
            const upper_bound: u64 = (real_cand + 1) * @as(u64, 8);
            print("DEBUG - lower_bound is {} and upper_bound is {}\n", .{ lower_bound, upper_bound });
            for (lower_bound..upper_bound) |next_cand| {
                if (find_output_value(next_cand) == desired_output) {
                    print("DEBUG - {} gives desired output of {}\n", .{ next_cand, desired_output });
                    next_candidates.put(next_cand, true) catch unreachable;
                }
            }
        }
        // Transfer next_candidates into candidates
        var cand_it_for_transfer = candidates.keyIterator();
        while (cand_it_for_transfer.next()) |k| {
            _ = candidates.remove(k.*);
        }
        var next_cand_it = next_candidates.keyIterator();
        while (next_cand_it.next()) |k| {
            // Memory management is fucking insane.
            // If I'd instead just done:
            // ```
            // _ = next_candidates.remove(k.*)
            // candidates.put(k.*) catch unreachable;
            // ```
            // Then - presumably because `k` is a pointer rather than the actual value - the value put into candidates will be some entirely different value than the one retrieved from `next_candidates`
            const actual_value = k.*;
            print("DEBUG - found {} in next_candidates (to be removed)\n", .{actual_value});
            _ = next_candidates.remove(actual_value);
            print("DEBUG - transferring {} from next_candidates to candidates for the next iteration\n", .{actual_value});
            candidates.put(actual_value, true) catch unreachable;
        }
    }

    print("Finished processing - all candidates are: ", .{});
    var lowest: u64 = 9999999999999999999;
    var cand_it = candidates.keyIterator();
    while (cand_it.next()) |c| {
        print("{}, ", .{c.*});
        if (c.* < lowest) {
            lowest = c.*;
        }
    }
    print("\n\nLowest is {}\n", .{lowest});
}

test "find_output_value" {
    try expect(find_output_value(448) == 7);
    try expect(find_output_value(449) == 7);
    try expect(find_output_value(450) == 5);
    try expect(find_output_value(451) == 4);
    try expect(find_output_value(452) == 5);
    try expect(find_output_value(453) == 6);
    try expect(find_output_value(454) == 2);
    try expect(find_output_value(455) == 7);
}
