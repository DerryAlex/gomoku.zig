const std = @import("std");
const Allocator = std.mem.Allocator;

const protocol = @import("../protocol.zig");
const GameManager = protocol.GameManager;

const Board = @import("board.zig").Board;
const search = @import("search.zig").search;

fn colorPromote(color: protocol.Color) @import("board.zig").Color {
    return switch (color) {
        .None => .None,
        .Black => .Black,
        .White => .White,
    };
}

pub const Brain = struct {
    manager: *GameManager,
    board: Board,

    const Self = @This();

    pub fn init(self: *Self, manager: *GameManager) error{OutOfMemory}!void {
        self.manager = manager;
        self.board = try Board.init(manager.board.dimension[0], manager.board.dimension[1], manager.allocator);
        errdefer self.board.deinit(manager.allocator);
        return;
    }

    pub fn deinit(self: Self) void {
        self.board.deinit();
    }

    fn update(self: *Self) void {
        var x: usize = 0;
        while (x < self.manager.board.dimension[0]) : (x += 1) {
            var y: usize = 0;
            while (y < self.manager.board.dimension[1]) : (y += 1) {
                if (colorPromote(self.manager.board.get([2]usize{ x, y })) != self.board.get([2]usize{ x, y })) {
                    self.board.update([2]usize{ x, y }, colorPromote(self.manager.board.get([2]usize{ x, y })));
                }
            }
        }
    }

    pub fn play(self: *Self) error{OutOfMemory}![2]usize {
        self.update();
        return search(self) catch |err| switch (err) {
            error.OutOfMemory => {
                return error.OutOfMemory;
            },
            error.TimeOut => self.randomPlay(),
        };
    }

    /// show debug info
    pub fn evaluate(self: *Self, x: usize, y: usize) void {
        _ = self;
        _ = x;
        _ = y;
        @import("../protocol.zig").response(.Message, "NNUE {d}", .{self.board.evaluateAllNnue()}); // TODO: remove when NNUE is done
    }

    fn randomPlay(self: *const Self) [2]usize {
        var randomAlgo = std.rand.DefaultPrng.init(0);
        const rng = randomAlgo.random();
        var position: [2]usize = undefined;
        while (true) {
            position[0] = rng.uintLessThan(usize, self.manager.board.dimension[0]);
            position[1] = rng.uintLessThan(usize, self.manager.board.dimension[1]);
            if (self.manager.board.get(position) == .None) {
                break;
            }
        }
        return position;
    }
};
