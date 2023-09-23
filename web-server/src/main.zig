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
    const address = try Address.resolveIp("127.0.0.1", 8080);

    try streamServer.listen(address);

    while (true) {
        const connection = try streamServer.accept();
        try handler(allocator, connection.stream);
    }
}

const ParsinError = error{
    MethodNotValid,
    VersionNotValid,
};

const Method = enum {
    GET,
    POST,
    PUT,
    PATCH,
    DELETE,

    pub fn fromString(s: []const u8) !Method {
        if (std.mem.eql(u8, "GET", s)) return .GET;
        if (std.mem.eql(u8, "POST", s)) return .POST;
        if (std.mem.eql(u8, "PUT", s)) return .PUT;
        if (std.mem.eql(u8, "PATCH", s)) return .PATCH;
        if (std.mem.eql(u8, "DELETE", s)) return .DELETE;
        return ParsinError.MethodNotValid;
    }
};

const Version = enum {
    @"1.1",
    @"2",

    pub fn fromString(s: []const u8) !Version {
        if (std.mem.eql(u8, "HTTP/1.1", s)) return .@"1.1";
        if (std.mem.eql(u8, "HTTP/2", s)) return .@"2";
        return ParsinError.VersionNotValid;
    }
};

const Request = struct {
    method: Method,
    path: []const u8,
    version: Version,
    headers: std.StringHashMap([]const u8),
    stream: net.Stream,

    pub fn body(self: Request) net.Stream.Reader {
        return self.stream.reader();
    }

    pub fn response(self: Request) net.Stream.Writer {
        return self.stream.writer();
    }

    pub fn debugPrint(self: *Request) void {
        print("method={}\npath={s}\nversion={}\n", .{ self.method, self.path, self.version });
        var headersIter = self.headers.iterator();
        while (headersIter.next()) |header| {
            print("{s}: {s}", .{ header.key_ptr.*, header.value_ptr.* });
        }
    }

    pub fn init(allocator: std.mem.Allocator, stream: net.Stream) !Request {
        var firstLine = try stream.reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
        firstLine = firstLine[0 .. firstLine.len - 1];
        var firstLineIter = std.mem.split(u8, firstLine, " ");

        const method = firstLineIter.next().?;
        const path = firstLineIter.next().?;
        const version = firstLineIter.next().?;

        var headers = std.StringHashMap([]const u8).init(allocator);

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

        return Request{
            .headers = headers,
            .path = path,
            .stream = stream,
            .method = try Method.fromString(method),
            .version = try Version.fromString(version),
        };
    }
};

fn handler(allocator: std.mem.Allocator, stream: net.Stream) !void {
    defer stream.close();

    var req = try Request.init(allocator, stream);
    req.debugPrint();
}
