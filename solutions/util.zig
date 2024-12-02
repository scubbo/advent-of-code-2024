// Unfortunately I have to put this in `solutions/` even though it more-properly belongs at a higher-level,
// because non-sibling imports require setting up a `build.zig` (https://old.reddit.com/r/Zig/comments/ra5qeo/import_of_file_outside_package_path/)
// and that seems awful.

const std = @import("std");

pub fn getInputFile(problemNumber: []const u8, isTestCase: bool) ![]u8 {
    return concatString("inputs/", try concatString(problemNumber, try concatString("/", try concatString(if (isTestCase) "test" else "real", ".txt"))));
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

const expect = @import("std").testing.expect;

test {
    const result = try concatString("abc", "def");
    try expect(std.mem.eql(u8, result, "abcdef"));
}

test "testGetInputFile" {
    const result = try getInputFile("01", true);
    try expect(std.mem.eql(u8, result, "inputs/01/test.txt"));

    const result1 = try getInputFile("42", false);
    try expect(std.mem.eql(u8, result1, "inputs/42/real.txt"));
}
