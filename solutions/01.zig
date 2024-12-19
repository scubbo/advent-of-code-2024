const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");

pub fn main() !void {
    const output = try part_two();
    print("{}\n", .{output});
}

pub fn part_one() !u32 {
    const arrays = try parseInputFileToArrays();
    const arr1 = arrays.first;
    const arr2 = arrays.second;

    // Everything below this is the actual logic
    const stdout = std.io.getStdOut().writer();
    std.mem.sort(u32, arr1, {}, comptime std.sort.asc(u32));
    std.mem.sort(u32, arr2, {}, comptime std.sort.asc(u32));

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

pub fn part_two() !u32 {
    const arrays = try parseInputFileToArrays();
    const arr1 = arrays.first;
    const arr2 = arrays.second;
    print("DEBUG - arr1 is {any}\narr2 is {any}\n", .{arr1, arr2});
    // Logic:
    // * Iterate over each array
    // * Count the number of occurrences
    // * For each number, increment the sum by (number * count_1 * count_2)
    // (Would technically be parallelizable if you wanted to get fancy, but JFC I'm not ready for that in Zig yet)

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var counts1 = std.AutoHashMap(u32, u32).init(allocator);
    var counts2 = std.AutoHashMap(u32, u32).init(allocator);
    // Later, we'll need to iterate over the keys of `counts1` to sum up the final value.
    // You'd think you could do this with:
    // ```
    // const iter = counts1.keyIterator();
    // while (try iter.next()) |key| {
    // ...
    // ```
    // But that gives an error that the iterator is a const pointer but `while` requires a mutable pointer.
    // So instead I preserve the encountered keys in this array so that we can then loop over them.
    // Ridiculous language.
    var preservedKeys = std.ArrayList(u32).init(allocator);
    for (arr1) |elem| {
        if (!counts1.contains(elem)) {
            try preservedKeys.append(elem);
            print("Added {} to the preservedKeys list\n", .{elem});
        }
        try counts1.put(elem, (counts1.get(elem) orelse 0) + 1);
        
    }
    for (arr2) |elem| {
        try counts2.put(elem, (counts2.get(elem) orelse 0) + 1);
    }

    print("Beginning the calculation", .{});
    var output: u32 = 0;
    for (preservedKeys.items) |key| {
        print("Operating on {} - at this point the output value is {}\n", .{key, output});
        const count1 = (counts1.get(key) orelse 0);
        const count2 = (counts2.get(key) orelse 0);
        const increment = key * count1 * count2;
        print("The increment for key {} is {} (calculated based on counts {} and {})\n", .{key, increment, count1, count2});
        output += increment;
    }
    return output;

}

fn parseInputFileToArrays() !struct { first: []u32, second: []u32 } {
    // Wow this _sucks_. But there's no way (that I know of?) to find the number of lines in a file without parsing it,
    // and we can't parse it without having created the array already, so... :shrug
    const isTestCase = true;
    const lengthOfArray: usize = if (isTestCase) 6 else 1000;
    var arr1: [lengthOfArray]u32 = undefined;
    var arr2: [lengthOfArray]u32 = undefined;

    // Reading the input...
    // Making use of example here: https://cookbook.ziglang.cc/01-01-read-file-line-by-line.html
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const path = try util.getInputFile("01", isTestCase);
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
    return .{ .first = &arr1, .second = &arr2 };
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

test "part one" {
    try expect(try part_one() == 11);
}

test "part two" {
    try expect(try part_two() == 31);
}
