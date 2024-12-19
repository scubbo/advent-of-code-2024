const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");

pub fn main() !void {
    const output = try part_one();
    print("{}\n", .{output});
}

pub fn part_one() !u32 {
    const isTestCase = true;
    // Reading the input...
    // Making use of example here: https://cookbook.ziglang.cc/01-01-read-file-line-by-line.html
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const path = try util.getInputFile("02", isTestCase);
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    // Wrap the file reader in a buffered reader.
    // Since it's usually faster to read a bunch of bytes at once.
    var buf_reader = std.io.bufferedReader(file.reader());
    const reader = buf_reader.reader();

    var line = std.ArrayList(u8).init(allocator);
    defer line.deinit();

    const writer = line.writer();
    var line_no: usize = 0;

    var safe_count: u32 = 0;

    while (reader.streamUntilDelimiter(writer, '\n', null)) {
        defer line.clearRetainingCapacity();
        line_no += 1;

        const report = try parseLineToNumbers(line.items, allocator);
        if (try is_safe(report)) {
            safe_count += 1;
        }
        report.deinit();


    }  else |err| switch (err) {
        error.EndOfStream => { // end of file
            if (line.items.len > 0) {
                line_no += 1;
                print("{d}--{s}\n", .{ line_no, line.items });
            }
        },
        else => return err, // Propagate error
    }
    return safe_count;
}

pub const IllegalDataError = error{
    TooSmall
};

// The logic given is:
// - "Levels are either all increasing or all decreasing"
// - "Adjacent levels differ by at least one and at most three"
//
// which can be rephrased (so as to avoid having to pass through the state of "is this an all-increasing or
// all-decreasing report?") as:
// - "The first pair of levels is within 1-3"
// - "For all triples in the report, both pairs have the same direction, and the final pair is within 1-3"
fn is_safe(reportAsArray: std.ArrayList(u32)) !bool {
    const report = reportAsArray.items;
    // Legality-check that the report contains at least two levels
    if (report.len < 2) {
        return IllegalDataError.TooSmall;
    }
    // First, check that the first pair of levels is within 1-3
    const diff_of_first_pair = util.diffOfNumbers(report[0], report[1]);
    if ((diff_of_first_pair < 1) or (diff_of_first_pair > 3)) {
        return false;
    }

    // Early return if the report contains only 2 levels
    if (report.len < 3) {
        return true;
    }

    // We know that the report contains at least 3 levels, so we can start a sliding comparison.
    var i: u32 = 0;
    while (i < (report.len - 2)) {
        if (
            (report[i] > report[i+1]) and (report[i+1] < report[i+2])
            or
            (report[i] < report[i+1] and (report[i+1] > report[i+2]))
        ) {
            return false;
        }
        const diff_of_second_pair = util.diffOfNumbers(report[i+1], report[i+2]);
        if ((diff_of_second_pair < 1) or (diff_of_second_pair > 3)) {
            return false;
        }
        i+=1;
    }

    return true;
}

// TODO - probably extract this to utils?
// (Though note that this differs from the example in 01.zig)
fn parseLineToNumbers(line: []u8, allocator: std.mem.Allocator) !std.ArrayList(u32) {
    var numbers = std.ArrayList(u32).init(allocator);
    // Feels _weird_ to be explicitly `deinit`-ing memory! This language is so fucked up.

    // https://stackoverflow.com/a/79199470/1040915
    var it = std.mem.splitScalar(u8, line, ' ');
    while (it.next()) |chunk| {
        print("Trying to parse {any}\n", .{chunk});
        const parsed = try std.fmt.parseInt(u32, chunk, 10);
        print("Parsed it to {}\n", .{parsed});
        try numbers.append(parsed);
    }
    return numbers;
}

const expect = std.testing.expect;

test "part one" {
    try expect(try part_one() == 2);
}