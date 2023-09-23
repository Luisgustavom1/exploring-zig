const std = @import("std");
const print = std.debug.print;
const net = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;

pub const io_mode = .evented;

const StringU8 = []const u8;

pub fn main() !void {
    var gpa = GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var streamServer = StreamServer.init(.{});
    defer streamServer.close();
    const address = try Address.resolveIp("127.0.0.1", 8080);

    try streamServer.listen(address);

    var frames = std.ArrayList(*Connection).init(allocator);
    while (true) {
        const connection = try streamServer.accept();
        var conn = try allocator.create(Connection);
        conn.* = .{
            .frame = async handler(allocator, connection.stream),
        };
        try frames.append(conn);
    }
}

const Connection = struct {
    frame: @Frame(handler),
};

const ParsinError = error{
    MethodNotValid,
    VersionNotValid,
    StatusNotValid,
};

const Method = enum {
    GET,
    POST,
    PUT,
    PATCH,
    DELETE,

    pub fn fromString(s: StringU8) !Method {
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

    pub fn fromString(s: StringU8) !Version {
        if (std.mem.eql(u8, "HTTP/1.1", s)) return .@"1.1";
        if (std.mem.eql(u8, "HTTP/2", s)) return .@"2";
        return ParsinError.VersionNotValid;
    }

    pub fn asString(self: Version) StringU8 {
        if (self == Version.@"1.1") return "HTTP/1.1";
        if (self == Version.@"2") return "HTTP/2";
        unreachable;
    }
};

const Status = enum {
    OK,

    pub fn asString(self: Status) StringU8 {
        if (self == Status.OK) return "OK";
        unreachable;
    }

    pub fn asNumber(self: Status) usize {
        if (self == Status.OK) return 200;
        unreachable;
    }
};

const Request = struct {
    method: Method,
    path: StringU8,
    version: Version,
    headers: std.StringHashMap(StringU8),
    stream: net.Stream,

    pub fn bodyReader(self: Request) net.Stream.Reader {
        return self.stream.reader();
    }

    pub fn response(self: Request) net.Stream.Writer {
        return self.stream.writer();
    }

    pub fn respond(self: *Request, status: Status, headers: ?std.StringHashMap(StringU8), body: StringU8) !void {
        var writer = self.response();
        try writer.print("{s} {} {s}\r\n", .{ self.version.asString(), status.asNumber(), status.asString() });

        if (headers) |headers_non_null| {
            var header_iter = headers_non_null.iterator();

            while (header_iter.next()) |header| {
                try writer.print("{s}: {s}\n", .{ header.key_ptr.*, header.value_ptr.* });
            }
        }
        try writer.print("\r\n", .{}); // Empty line

        _ = try writer.write(body);
    }

    pub fn debugPrint(self: *Request) void {
        print("method={}\npath={s}\nversion={s}\n", .{ self.method, self.path, self.version.asString() });
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

        var headers = std.StringHashMap(StringU8).init(allocator);

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
    if (std.mem.eql(u8, req.path, "/sleep")) std.time.sleep(std.time.ns_per_s * 10);
    req.debugPrint();

    try req.respond(Status.OK, null, "Hello oooo\r\n");
}
