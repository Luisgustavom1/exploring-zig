const std = @import("std");

const print = std.debug.print;
const assert = std.debug.assert;

pub fn main() !void {
   const stdout = std.io.getStdOut().writer();
    try stdout.print("Hello, {s}\n", .{"world"});

    std.debug.print("shorthand of std.io.getStdOut().writer()\n\n", .{});

    // integer
    const integer32: i32 = 1 + 1;
    print("1 + 1 = {}\n", .{integer32});

    // float 
    const myFloat: f32 = 6.0 / 3.0;
    print("6.0 / 3.0 = {}\n", .{myFloat});

    // boolean
    print("and -> {}\n", .{true and false});
    print("or -> {}\n", .{true or false});
    print("! -> {}\n", .{!true});

    // optional value
    var my_optional: ?[]const u8 = null;
    assert(my_optional == null);

    print("my optional type: {}\nvalue: {?s}\n", .{
        @TypeOf(my_optional), my_optional,
    });

    my_optional = "oi";
    assert(my_optional != null);

    print("my optional type: {}\nvalue: {?s}\n", .{
        @TypeOf(my_optional), my_optional,
    });

    // error union
    var number_or_error: anyerror!i32 = error.ArgNotFound;

    print("my error union\ntype: {}\nvalue: {!}\n", .{
        @TypeOf(number_or_error), number_or_error,
    });
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
