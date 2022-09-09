const std = @import("std");
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const protocol = @import("protocol.zig");
const Command = protocol.Command;
const GameManager = protocol.GameManager;
const response = protocol.response;
const scanner = @import("lib/scanner.zig").scanner;

pub fn main() !void {
    var gpa = GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) {
        @panic("leak");
    };
    const allocator = gpa.allocator();
    var stdin_scanner = scanner(std.io.getStdIn().reader());
    var manager: GameManager = undefined;
    while (true) {
        var command = try stdin_scanner.scanAlloc(Command, allocator);
        defer command.deinit();
        switch (command) {
            .Start => {
                manager = try GameManager.init(command.Start.size, command.Start.size, allocator);
                response(.Ok, "", .{});
            },
            .Rectstart => {
                manager = try GameManager.init(command.Rectstart.x, command.Rectstart.y, allocator);
                response(.Ok, "", .{});
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
