// Unfortunately I have to put this in `solutions/` even though it more-properly belongs at a higher-level,
// because non-sibling imports require setting up a `build.zig` (https://old.reddit.com/r/Zig/comments/ra5qeo/import_of_file_outside_package_path/)
// and that seems awful.

const std = @import("std");

pub fn getInputFile(problemNumber: []const u8, isTestCase: bool) ![]u8 {
    return concatString("inputs/", try concatString(problemNumber, try concatString("/", try concatString(if (isTestCase) "test" else "real", ".txt"))));
}

// Technically this could be implemented as just repeated calls to `concatString`, but I _guess_ this is more efficient?
// (I. Hate. Manual memory allocation)
fn concatStrings(strings: []const []const u8) ![]u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var totalLength: usize = 0;
    for (strings) |string| {
        totalLength += string.len;
    }
    var combined = try allocator.alloc(u8, totalLength);
    var combinedIndexSoFar: usize = 0;
    for (strings) |string| {
        @memcpy(combined[combinedIndexSoFar..(combinedIndexSoFar + string.len)], string);
        combinedIndexSoFar += string.len;
    }
    return combined;
}

fn concatString(a: []const u8, b: []const u8) ![]u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    // I don't recall where the below came from, but it causes a `[gpa] (err): memory address 0x10383f000 leaked:` when
    // kept in, so...dropping it! :P
    //
    // defer {
    //     const deinit_status = gpa.deinit();
    //     //fail test; can't try in defer as defer is executed after we return
    //     if (deinit_status == .leak) expect(false) catch @panic("TEST FAIL");
    // }

    return concat(u8, allocator, a, b);
}

// https://www.openmymind.net/Zigs-memcpy-copyForwards-and-copyBackwards/
fn concat(comptime T: type, allocator: std.mem.Allocator, arr1: []const T, arr2: []const T) ![]T {
    var combined = try allocator.alloc(T, arr1.len + arr2.len);
    @memcpy(combined[0..arr1.len], arr1);
    @memcpy(combined[arr1.len..], arr2);
    return combined;
}

// Ugh. There are a _ton_ of problems with this because of overflow nonsense - but it's good enough to use until
// test cases demonstrate that it's not.
pub fn diffOfNumbers(a: u32, b: u32) u32 {
    if (a > b) {
        return a - b;
    } else {
        return b - a;
    }
}

const expect = @import("std").testing.expect;

test {
    const result = try concatString("abc", "def");
    try expect(std.mem.eql(u8, result, "abcdef"));
}

test "concatStrings" {
    const result = try concatStrings(&.{ "hello ", "again, ", "friend of ", "a friend" });
    try expect(std.mem.eql(u8, result, "hello again, friend of a friend"));
}

test "testGetInputFile" {
    const result = try getInputFile("01", true);
    try expect(std.mem.eql(u8, result, "inputs/01/test.txt"));

    const result1 = try getInputFile("42", false);
    try expect(std.mem.eql(u8, result1, "inputs/42/real.txt"));
}
