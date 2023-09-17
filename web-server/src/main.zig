const std = @import("std");
const print = std.debug.print;
const net = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;

pub const io_mode = .evented;

pub fn main() !void {
    var gpa = GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var streamServer = StreamServer.init(.{});
    defer streamServer.close();
    const address = try Address.resolveIp("127.0.0.1", 8000);

    try streamServer.listen(address);

    while (true) {
        const connection = try streamServer.accept();
        try handler(allocator, connection.stream);
    }
}

fn handler(allocator: std.mem.Allocator, stream: net.Stream) !void {
    defer stream.close();

    var firstLine = try stream.reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
    firstLine = firstLine[0..firstLine.len];
    var firstLineIter = std.mem.split(u8, firstLine, " ");

    const method = firstLineIter.next().?; // test ?
    const path = firstLineIter.next().?;
    const version = firstLineIter.next().?;

    var headers = std.StringArrayHashMap([]const u8).init(allocator);

    while (true) {
        var headerLine = try stream.reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
        if (headerLine.len == 1 and std.mem.eql(u8, headerLine, "\r")) break;

        headerLine = headerLine[0..headerLine.len];
        var headerLineIter = std.mem.split(u8, headerLine, ":");
        const key = headerLineIter.next().?;
        var value = headerLineIter.next().?;

        // remove first value whitespace
        if (value[0] == ' ') value = value[1..];

        try headers.put(key, value);
    }

    print("method={s}\npath={s}\nversion={s}\n", .{ method, path, version });
    var headersIter = headers.iterator();
    while (headersIter.next()) |header| {
        print("{s}: {s}", .{ header.key_ptr.*, header.value_ptr.* });
    }
}
