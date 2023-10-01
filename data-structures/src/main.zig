const std = @import("std");

const IntStack = Stack(i32);
const IntQueue = Queue(i32);

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var stack = IntStack.init(alloc);

    try stack.push(1);
    try stack.push(15);
    stack.print();

    var pop = stack.pop();
    std.log.info("pop {?d}\n", .{pop});
    pop = stack.pop();
    stack.print();
    std.log.info("pop {?d}\n", .{pop});

    std.log.info("queue -> \n", .{});
    var queue = IntQueue.init(alloc);

    try queue.enqueue(1);
    try queue.enqueue(9);
    try queue.enqueue(4);

    std.log.info("size -> {d}", .{queue.len});
    std.log.info("dequeued {?d}\n", .{queue.dequeue()});
    std.log.info("dequeued {?d}\n", .{queue.dequeue()});
    std.log.info("size -> {d}", .{queue.len});
    std.log.info("dequeued {?d}\n", .{queue.dequeue()});

    try queue.enqueue(91);
    std.log.info("dequeued {?d}\n", .{queue.dequeue()});
}

fn ListNode(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,
        next: ?*Self,
    };
}

fn DoubleListNode(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,
        next: ?*Self,
        prev: ?*Self,
    };
}

fn Stack(comptime T: type) type {
    return struct {
        const Self = @This();

        head: ?*ListNode(T),
        alloc: std.mem.Allocator,
        len: usize,

        fn init(alloc: std.mem.Allocator) Self {
            return .{
                .alloc = alloc,
                .head = null,
                .len = 0,
            };
        }

        fn push(self: *Self, value: T) !void {
            var node = try self.alloc.create(ListNode(T));
            node.value = value;

            var head = self.head;
            node.next = head;
            self.head = node;

            self.len += 1;
        }

        fn pop(self: *Self) ?T {
            if (self.head) |head| {
                self.head = head.next;

                var value = head.value;
                self.len -= 1;
                self.alloc.destroy(head);

                return value;
            }

            return null;
        }

        fn print(self: *Self) void {
            var curr = self.head;
            std.log.info("stack: {}", .{self.len});
            while (curr) |node| {
                std.log.info("-> {d}", .{node.value});
                curr = node.next;
            }
        }
    };
}

fn Queue(comptime T: type) type {
    return struct {
        const Self = @This();

        head: ?*DoubleListNode(T),
        tail: ?*DoubleListNode(T),
        len: usize,
        alloc: std.mem.Allocator,

        fn init(alloc: std.mem.Allocator) Self {
            return .{
                .alloc = alloc,
                .head = null,
                .tail = null,
                .len = 0,
            };
        }

        fn enqueue(self: *Self, value: T) !void {
            var node = try self.alloc.create(DoubleListNode(T));

            node.prev = null;
            node.value = value;

            if (self.head == null) {
                self.head = node;
            } else {
                node.next = self.tail;

                if (self.tail) |t| {
                    t.prev = node;
                }
            }

            self.tail = node;
            self.len += 1;
        }

        fn dequeue(self: *Self) ?T {
            self.len -= 1;

            if (self.head) |h| {
                self.head = h.prev;
                const value = h.value;

                self.alloc.destroy(h);

                return value;
            }

            return null;
        }
    };
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
