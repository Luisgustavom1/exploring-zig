const std = @import("std");
const net = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;

pub const io_mode = .evented;

pub fn main() !void {
    const streamServer = StreamServer.init(.{});
    defer streamServer.deinit();
    const address = try Address.resolveIp("127.0.0.1", 8080);

    streamServer.listen_address(address);
}
