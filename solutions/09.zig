const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");

pub fn main() !void {
    const response = try part_two(false);
    print("{}\n", .{response});
}

// There's _probably_ a super-clever way of doing this without actually expanding out the disk map, using dual-pointers
// and keeping track of how much of each "chunk" has been consumed at each step - but, after thinking it over for a bit,
// I couldn't figure out how to determine when to terminate (i.e. when enough blocks have been moved to make everything
// contiguous), so I'm going for the naive approach - expand out the disk-map, then swap blocks one-by-one.
//
// ...huh, that executed _way_ faster than I feared.
fn part_one(is_test_case: bool) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("09", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    var disk = std.ArrayList(?u32).init(allocator);
    defer disk.deinit();

    var is_in_disk = true;
    var disk_id: u32 = 0;
    for (data) |c| {
        if (c == '\n') {
            continue;
        }
        const count = c - 48; // Why 48? Just because, I guess :shrug: ASCII for `2` is 50, and so...
        for (0..count) |_| {
            if (is_in_disk) {
                try disk.append(disk_id);
            } else {
                try disk.append(null);
            }
        }
        if (!is_in_disk) {
            disk_id += 1;
        }
        is_in_disk = !is_in_disk;
    }
    print("DEBUG - actual disk is {any}\n", .{disk.items});

    // We could _probably_ iterate over the disk from both ends and _just_ sum up the calculated values to get the
    // answer (which would be more space-efficient) - but that way I'd have no chance of debugging if something goes
    // wrong. I'll instead construct the _actually_ defragged disk, so that I can visually compare it with how it's
    // supposed to look.
    var left_pointer: usize = 0;
    var right_pointer: usize = disk.items.len - 1;
    var defragged_disk = std.ArrayList(u32).init(allocator);
    defer defragged_disk.deinit();
    while (true) : (left_pointer += 1) {
        const value_in_original_disk = disk.items[left_pointer];
        if (value_in_original_disk != null) {
            try defragged_disk.append(value_in_original_disk.?);
        } else {
            // Position of left_pointer is inside a space in the original disk =>
            // Move the right_pointer left until it finds a block, then insert that into the defragged disk
            while (disk.items[right_pointer] == null) {
                right_pointer -= 1;
            }
            try defragged_disk.append(disk.items[right_pointer].?);
            right_pointer -= 1;
        }
        if (right_pointer == left_pointer) {
            break;
        }
    }
    print("DEBUG - defragged disk is {any}\n", .{defragged_disk.items});

    var total: u64 = 0;
    var idx: u32 = 0;
    while (idx < defragged_disk.items.len) : (idx += 1) {
        total += idx * defragged_disk.items[idx];
    }

    return total;
}

fn part_two(is_test_case: bool) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_file = try util.getInputFile("09", is_test_case);
    const data = try util.readAllInputWithAllocator(input_file, allocator);
    defer allocator.free(data);

    var disk = std.ArrayList(?u32).init(allocator);
    defer disk.deinit();

    var is_in_file = true;
    var file_id: u32 = 0;
    var file_start_indices = std.AutoHashMap(u32, usize).init(allocator);
    defer file_start_indices.deinit();
    // If we wanted, we could probably store "DiskInfo" in a struct and thus in a single HashMap, but...ehhh...
    var file_sizes = std.AutoHashMap(u32, usize).init(allocator);
    defer file_sizes.deinit();
    for (data) |c| {
        if (c == '\n') {
            continue;
        }
        const count = c - 48; // Why 48? Just because, I guess :shrug: ASCII for `2` is 50, and so...
        if (is_in_file) {
            try file_start_indices.put(file_id, disk.items.len);
        }
        for (0..count) |_| {
            if (is_in_file) {
                try disk.append(file_id);
                try file_sizes.put(file_id, count);
            } else {
                try disk.append(null);
            }
        }
        if (!is_in_file) {
            file_id += 1;
        }
        is_in_file = !is_in_file;
    }
    const highest_file_id = file_id;
    print("DEBUG - actual disk is {any}\n", .{disk.items});
    print("DEBUG - highest_file_id is {}\n", .{highest_file_id});
    print("DEBUG - file_start_indices is:\n", .{});
    var it_dsi = file_start_indices.iterator();
    while (it_dsi.next()) |kv| {
        print("  {}: {}\n", .{ kv.key_ptr.*, kv.value_ptr.* });
    }
    print("DEBUG - file_sizes is:\n", .{});
    var it_ds = file_sizes.iterator();
    while (it_ds.next()) |kv| {
        print("  {}: {}\n", .{ kv.key_ptr.*, kv.value_ptr.* });
    }

    // Zig does not support decreasing ranges :'(
    // for (highest_file_id..0) |file_id_to_move| {
    for (0..highest_file_id) |file_i| {
        const file_id_to_move = highest_file_id - file_i;
        print("DEBUG - trying to move file with id {}\n", .{file_id_to_move});
        const file_id_as_u32: u32 = @intCast(file_id_to_move);
        const original_start_index = file_start_indices.get(file_id_as_u32).?;
        const file_size = file_sizes.get(file_id_as_u32).?;
        var left_pointer: usize = 0;
        // I don't _think_ we can be smarter about jumping forward more than 1 at a time - at least, not without
        // returning information from within `hasSpaceToMove`. In particular, we can't jump forward `file_size` -
        // consider trying to move a file of size 4 into the following disk:
        //    X..X....X
        // if we jumped forward 4 from index 1, we'd land partway through the following 4-gap, and miss it.
        while (left_pointer < original_start_index) : (left_pointer += 1) {
            if (hasSpaceToMove(disk, left_pointer, file_size)) {
                for (0..file_size) |i| {
                    disk.items[left_pointer + i] = file_id_as_u32;
                    disk.items[original_start_index + i] = null;
                }
                break;
            }
        }
    }

    print("DEBUG - defragged disk is {any}\n", .{disk.items});

    var total: u64 = 0;
    var idx: u32 = 0;
    while (idx < disk.items.len) : (idx += 1) {
        total += idx * (disk.items[idx] orelse 0);
    }

    return total;
}

fn hasSpaceToMove(disk: std.ArrayList(?u32), pointer: usize, file_size: usize) bool {
    for (0..file_size) |i| {
        if (disk.items[pointer + i] != null) {
            return false;
        }
    }
    print("DEBUG - found space to move - to location {}\n", .{pointer});
    return true;
}

const expect = std.testing.expect;

test "part_one" {
    const part_one_response = try part_one(true);
    print("DEBUG - part_one_response is {}\n", .{part_one_response});
    try expect(part_one_response == 1928);
}

test "part_two" {
    const part_two_response = try part_two(true);
    print("DEBUG - part_two_response is {}\n", .{part_two_response});
    try expect(part_two_response == 2858);
}
