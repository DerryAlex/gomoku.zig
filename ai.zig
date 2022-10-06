const std = @import("std");
const root = @import("root");
const Allocator = std.mem.Allocator;
const protocol = root.protocol;
const GameManager = protocol.GameManager;
pub const board = @import("ai/board.zig");
pub const evaluate = @import("ai/evaluate.zig");
pub const nnue = @import("ai/nnue.zig");
pub const search = @import("ai/search.zig").search;
const Board = board.Board;
const Nnue = nnue.Nnue;
const evaluateAllClassical = evaluate.evaluateAllClassical;
const evaluateAllNnue = evaluate.evaluateAllNnue;

fn colorPromote(color: protocol.Color) board.Color {
    return switch (color) {
        .None => .None,
        .Black => .Black,
        .White => .White,
    };
}

pub const Brain = struct {
    manager: *GameManager,
    board: Board,
    nnue: Nnue,

    const Self = @This();

    pub fn init(self: *Self, manager: *GameManager) !void {
        self.manager = manager;
        self.board = try Board.init(manager.board.dimension[0], manager.board.dimension[1], manager.allocator);
        errdefer self.board.deinit();
        const cwd = std.fs.cwd();
        const nnue_data = try cwd.openFile("data/nnue.bin", .{});
        defer nnue_data.close();
        const reader = nnue_data.reader();
        self.nnue = try Nnue.init(reader);
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
                if (colorPromote(self.manager.board.get(.{ x, y })) != self.board.get(.{ x, y })) {
                    self.board.update(.{ x, y }, colorPromote(self.manager.board.get(.{ x, y })));
                }
            }
        }
    }

    pub fn play(self: *Self) ![2]usize {
        self.update();
        return search(self) catch |err| switch (err) {
            error.TimeOut => self.randomPlay(),
            else => {
                return err;
            },
        };
    }

    /// show debug info
    pub fn evaluate(self: *Self, x: usize, y: usize) !void {
        _ = x;
        _ = y;
        self.update();
        self.board.display();
        const score = evaluateAllClassical(self);
        const nnue_score = evaluateAllNnue(self);
        protocol.response(.Message, "eval {} (nnue {})", .{ score, nnue_score });
    }

    fn randomPlay(self: *const Self) [2]usize {
        var randomAlgo = std.rand.DefaultPrng.init(0);
        const rng = randomAlgo.random();
        var position: [2]usize = undefined;
        while (true) {
            position = .{ rng.uintLessThan(usize, self.manager.board.dimension[0]), rng.uintLessThan(usize, self.manager.board.dimension[1]) };
            if (self.manager.board.get(position) == .None) {
                break;
            }
        }
        return position;
    }
};
