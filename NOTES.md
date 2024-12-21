Notes, thoughts, or questions that arose as I implemented the solutions. Hopefully I am able to go back and answer these questions as I keep learning!

# Things I like

* [Continue expressions](https://zig-by-example.com/while)
* Built in optionals (with `orelse`)
* Better error-handling than GoLang's (though that bar is set _real_ low). I have only just scratched the surface, though, it looks interestingly powerful - might well be even better than I've realized at this point!
* Creation of "bare" structs - i.e. you can do `myFunction(.{thing})` rather than `myFunction(StructName{thing})` (looking at you, GoLang)

# Things that I've found missing from this language

Hmmmm, right now it seems even worse than GoLang. Though the Error handling is _so_ much better that I can forgive much of this (which can be hacked-in to personal taste with utility functions, whereas you cannot fix GoLang's Errors as they are built-in language features).

* [String concatenation](https://old.reddit.com/r/Zig/comments/bfcsul/concatenating_zig_strings/)
* [String equality](https://nofmal.github.io/zig-with-example/string-handling/#string-equal)
* Switching on strings

## Not "missing", but...

It irritates me that Zig - like GoLang - has continued C's demonstrably-incorrect inversion of the addressing/dereferencing operators. If `*T` is the type-symbol for "_a pointer to a type `T`_", then, for a value `t`, the symbol for "_a pointer to the value `t`_" should be `*t`, not `&t`.

Plus, needing semi-colons on the end of every line? Come _on_, my guy.

# Questions

## (From Ziglings)

[Problem 40](https://codeberg.org/ziglings/exercises/src/commit/8da60edb82b25ac913033b2f0edb63eea212c0d0/exercises/040_pointers2.zig) says "_You can always make a const pointer to a mutable value (var), but you cannot make a var pointer to an immutable value (const)._" - which, sure, fair enough (I mean, not really, but I'm not going to argue with it...), but that's not what's presented in the problem - the original code is:

```
    const a: u8 = 12;
    const b: *u8 = &a; // fix this!
```

which is a constant pointer to a _constant_ value - which shouldn't be an issue?

## What's the idiomatic way to run Zig tests?

I've tried - using references like [this](https://zig.guide/build-system/zig-build), [this](https://old.reddit.com/r/Zig/comments/y65qa6/how_to_test_every_file_in_a_simple_zig_project/), and [this](https://www.openmymind.net/Using-A-Custom-Test-Runner-In-Zig/) - to set up `build.zig` so that I could run `zig build test` and thus run every test in my files, but that didn't work:

```zig
// build.zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const main_tests = b.addTest(.{ .root_source_file = b.path("main.zig") });
    const build_mode = b.standardReleaseOptions();
    main_tests.setBuildMode(build_mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}

// main.zig
pub const one = @import("solutions/01.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
```

As-written, `zig build test` gives:

```
/Users/scubbo/Code/advent-of-code-2024/build.zig:19:25: error: no field or member function named 'standardReleaseOptions' in 'Build'
    const build_mode = b.standardReleaseOptions();
```

With that line (and the following one deleted), `zig build test` completes silently, even with a failing test.

And this setup _still_ isn't great, because it's necessary to manually import every file to `main.zig`'s imports.

Hence the `test.sh` workaround script. It's not great, because it will error-out on the first failure (rather than accumulating failures from all files) - but it does the job!

Refer to [here](https://ziglang.org/documentation/master/#Zig-Test) for more info - which I only found after writing that hacky script.

## Why can't a string-literal be passed to a function that accepts a `[]8`?

That is, why is this illegal?

```
fn doIt(string: []u8) []u8 {
    return "prefix" + string;
}

const expect = @import("std").testing.expect;

test {
    expect(std.mem.eql(u8, doIt("foo"), "prefixfoo"));
}
```

I can fix it by changing the type signature to accept `[]const u8`, but (I think?) that then means that I can't call the function with non-const-length strings - including strings read from files.

[This](https://stackoverflow.com/questions/72736997/how-to-pass-a-c-string-into-a-zig-function-expecting-a-zig-string) link refers to `[]const u8` as a "Zig-style string-slice", but also refers to `[*c]const u8` as a "c_string", so...:shrug:?

---

Further questioning on this [here](https://stackoverflow.com/questions/79298713/how-can-i-write-a-zig-function-that-can-accept-and-return-strings).

## Why can't I iterate over a HashMap?

The following code:

```zig
const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var hashMap = std.AutoHashMap(u32, u32).init(allocator);

    try hashMap.put(2, 5);
    try hashMap.put(1, 35);
    try hashMap.put(4, 20);

    const iter = hashMap.keyIterator();
    while (try iter.next()) |key| {
        print("{}\n", .{key});
    }
}
```

gives:

```
scratch.zig:15:20: error: expected type '*hash_map.HashMapUnmanaged(u32,u32,hash_map.AutoContext(u32),80).FieldIterator(u32)', found '*const hash_map.HashMapUnmanaged(u32,u32,hash_map.AutoContext(u32),80).FieldIterator(u32)'
    while (try iter.next()) |key| {
               ~~~~^~~~~
scratch.zig:15:20: note: cast discards const qualifier
/Users/scubbo/zig/zig-macos-x86_64-0.14.0-dev.2362+a47aa9dd9/lib/std/hash_map.zig:894:35: note: parameter type declared here
                pub fn next(self: *@This()) ?*T {
```

I _think_ this means that the pointer to the Iterator is a Const-pointer and `.next()` expects a mutable pointer. But, if so - how do we get a mutable pointer from a const? I tried `@ptrCast` but that gave a similar error.
