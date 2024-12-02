const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");

pub fn main() !u32 {
    var arr1: [1000]u32 = undefined;
    var arr2: [1000]u32 = undefined;

    // Reading the input...
    // Making use of example here: https://cookbook.ziglang.cc/01-01-read-file-line-by-line.html
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const path = try util.getInputFile("01", true);
    std.debug.print("Path is {s}\n", .{path});
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

    while (reader.streamUntilDelimiter(writer, '\n', null)) {
        // Clear the line so we can reuse it.
        defer line.clearRetainingCapacity();
        line_no += 1;

        print("{d}--{s}\n", .{ line_no, line.items });

        const values = parseLineToNumbers(line.items);
        arr1[line_no - 1] = values.first;
        arr2[line_no - 1] = values.second;
    } else |err| switch (err) {
        error.EndOfStream => { // end of file
            if (line.items.len > 0) {
                line_no += 1;
                print("{d}--{s}\n", .{ line_no, line.items });
            }
        },
        else => return err, // Propagate error
    }

    // Everything below this is the actual logic
    const stdout = std.io.getStdOut().writer();
    std.mem.sort(u32, &arr1, {}, comptime std.sort.asc(u32));
    std.mem.sort(u32, &arr2, {}, comptime std.sort.asc(u32));

    var sum: u32 = 0;
    for (0..arr1.len) |index| {
        const val1 = arr1[index];
        const val2 = arr2[index];
        if (val1 > val2) {
            sum += (val1 -% val2);
        } else {
            sum += (val2 -% val1);
        }
    }
    try stdout.print("{}", .{sum});
    // Only used for testing - but later we'll have this return to an actual higher-level `main` function and have
    // _that_ do printing.
    return sum;
}

fn parseLineToNumbers(line: []u8) struct { first: u32, second: u32 } {
    var first: u32 = 0;
    var second: u32 = 0;
    var isInFirst = true;
    for (line) |char| {
        if (char == ' ') {
            print("found a space\n", .{});
            isInFirst = false;
            continue;
        }
        if (isInFirst) {
            print("first\n", .{});
            first += (char - 48);
            print("{}\n", .{first});
            first *= 10;
            print("{}\n", .{first});
        } else {
            print("second\n", .{});
            second += (char - 48);
            print("{}\n", .{second});
            second *= 10;
            print("{}\n", .{second});
        }
    }
    return .{ .first = first / 10, .second = second / 10 };
}

const expect = std.testing.expect;

test {
    const filePath = try util.getInputFile("01", true);
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}\n\n", .{filePath});
    try expect(try main() == 11);
}
