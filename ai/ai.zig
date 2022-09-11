const std = @import("std");
const Allocator = std.mem.Allocator;

const protocol = @import("../protocol.zig");
const GameManager = protocol.GameManager;

const Board = @import("board.zig").Board;
const Nnue = @import("nnue.zig").Nnue;
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
    nnue: Nnue,

    const Self = @This();

    pub fn init(self: *Self, manager: *GameManager) !void {
        self.manager = manager;
        self.board = try Board.init(manager.board.dimension[0], manager.board.dimension[1], manager.allocator);
        errdefer self.board.deinit();
        const cwd = std.fs.cwd();
        const nnue_data = try cwd.openFile("ai/nnue.bin", .{});
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
    pub fn evaluate(self: *Self, x: usize, y: usize) !void {
        _ = self;
        _ = x;
        _ = y;
        const evaluators = @import("evaluate.zig");
        const old_nnue_score = evaluators.evaluateAllNnue(self);
        const classical_score = evaluators.evaluateAllClassical(self);
        var expect_score = classical_score;
        if (expect_score > 30000) {
            expect_score = 30000;
        }
        else if (expect_score < -30000) {
            expect_score = 30000;
        }
        self.nnue.backwardPropagation(@truncate(i16, expect_score), 0.0003);
        const new_nnue_score = evaluators.evaluateAllNnue(self);
        protocol.response(.Message, "std = {}, nnue(old) = {}, nnue(new) = {}", .{classical_score, old_nnue_score, new_nnue_score});
        const cwd = std.fs.cwd();
        const new_nnue = try cwd.createFile("nnue_new.bin", .{});
        defer new_nnue.close();
        const writer = new_nnue.writer();
        try self.nnue.net.store(writer);
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
