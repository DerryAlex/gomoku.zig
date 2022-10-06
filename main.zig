const std = @import("std");
pub const lib = @import("lib.zig");
pub const ai = @import("ai.zig");
pub const protocol = @import("protocol.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) {
        @panic("leak");
    };
    const allocator = gpa.allocator();
    var stdin_scanner = lib.scanner.scanner(std.io.getStdIn().reader());
    var manager: protocol.GameManager = undefined;
    while (true) {
        var command = stdin_scanner.scanAlloc(protocol.Command, allocator) catch |err| switch (err) {
            error.InvalidCommand => {
                protocol.response(.Unknown, "Invalid Command", .{});
                continue;
            },
            else => {
                return err;
            },
        };
        defer command.deinit();
        switch (command) {
            .Start => {
                manager = try protocol.GameManager.init(command.Start.size, command.Start.size, allocator);
                protocol.response(.Ok, "", .{});
            },
            .Rectstart => {
                manager = try protocol.GameManager.init(command.Rectstart.x, command.Rectstart.y, allocator);
                protocol.response(.Ok, "", .{});
            },
            .End => {
                manager.deinit();
                break;
            },
            else => {
                try manager.process(command);
            },
        }
    }
}
