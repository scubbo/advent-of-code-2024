const std = @import("std");

// Unfortunately Zig doesn't appear to support dynamic imports - that is, non-literal arguments to `@import` -
// so we can't do `const module = @import(util.concatString(&.{"solutions/", problem_number, ".zig"}))`

const problem_one = @import("solutions/01.zig");

pub fn main() void {
    // std.debug.print("There are {d} args:\n", .{std.os.argv.len});
    // for (std.os.argv) |arg| {
    //     std.debug.print("  {s}\n", .{arg});
    // }
    const args = std.os.argv;
    const problem_number = parse_input_as_number(args[1]);
    const sub_problem_number = parse_input_as_number(args[2]);
    const module = switch (problem_number) {
        1 => {
            return problem_one;
        },
        else => {
            unreachable;
        },
    };
    switch (sub_problem_number) {
        1 => {
            module.part_one();
        },
        2 => {
            module.part_two();
        },
        else => {
            unreachable;
        },
    }
}

fn parse_input_as_number(input: [*:0]u8) i32 {
    // We _should_ be able to just use `try std.fmt.parseInt(i32, input)` - but that complains with
    // `expected type '[]const u8', found '[*:0]u8'`
    // and I CBA to figure out how to do that conversion when I have the time pressure of solving problems!
    // That can be for later learning :P
    var output_value: i32 = 0;
    for (input) |char| {
        output_value *= 10;
        output_value + char;
    }
    return output_value;
}
