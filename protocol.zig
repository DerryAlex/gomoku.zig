const builtin = @import("builtin");
const std = @import("std");
const root = @import("root");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Array = root.lib.array.Array;
const Brain = root.ai.Brain;

pub const Color = enum {
    None,
    Black,
    White,
};

const Field = enum {
    None,
    Own,
    Opponent,
    Winning,
};
const GameType = enum {
    Human,
    Brain,
    Tournament,
    Network,
};
const Rule = struct {
    mask: u3,

    const ExactFive = 1;
    const Continuous = 2;
    const Renju = 4;

    /// Exactly five in a row win
    pub inline fn isExactFive(self: Rule) bool {
        return self.mask & ExactFive != 0;
    }

    /// Continuous game
    pub inline fn isContinuous(self: Rule) bool {
        return self.mask & Continuous != 0;
    }

    /// Renju
    pub inline fn isRenju(self: Rule) bool {
        return self.mask & Renju != 0;
    }
};

/// Gomocup Protocol parser
pub const Command = union(enum) {
    // Mandatory commands
    Start: Start,
    Turn: Turn,
    Begin: void,
    Board: Board,
    Info: Info,
    End: void,
    About: void,
    // Optional commands
    Rectstart: Turn,
    Restart: void,
    Takeback: Turn,
    Play: Turn,

    const Self = @This();

    pub const Start = struct {
        size: usize,

        pub fn scan(scanner: anytype) !Start {
            try scanner.skipWhitespaces();
            const size = try scanner.scan(usize);
            return Start{ .size = size };
        }
    };

    pub const Turn = struct {
        x: usize, // width for Rectstart
        y: usize, // height for Rectstart

        pub fn scan(scanner: anytype) !Turn {
            try scanner.skipWhitespaces();
            const x = try scanner.scan(usize);
            _ = try scanner.scanUnicodeChar(); // skip ','
            const y = try scanner.scan(usize);
            return Turn{ .x = x, .y = y };
        }
    };

    pub const Board = struct {
        data: []Datum,
        allocator: Allocator,

        pub const Datum = struct {
            x: usize,
            y: usize,
            field: Field,
        };

        pub fn scanAlloc(scanner: anytype, allocator: Allocator) !Board {
            var array_list = ArrayList(Datum).init(allocator);
            errdefer array_list.deinit();
            while (true) {
                try scanner.skipWhitespaces();
                const x = scanner.scan(usize) catch |err| switch (err) {
                    error.InvalidCharacter => {
                        var buffer: [10]u8 = undefined;
                        const command = try scanner.scanUtf8String(buffer[0..]);
                        if (std.mem.eql(u8, command, "DONE")) {
                            break;
                        } else {
                            return error.InvalidCommand;
                        }
                    },
                    else => {
                        return err;
                    },
                };
                _ = try scanner.scanUnicodeChar(); // skip ','
                const y = try scanner.scan(usize);
                _ = try scanner.scanUnicodeChar(); // skip ','
                const field: Field = switch (try scanner.scan(u2)) {
                    1 => .Own,
                    2 => .Opponent,
                    3 => .Winning,
                    else => {
                        return error.InvalidCommand;
                    },
                };
                try array_list.append(Datum{ .x = x, .y = y, .field = field });
            }
            return Board{ .data = array_list.toOwnedSlice(), .allocator = allocator };
        }

        pub fn deinit(self: Board) void {
            self.allocator.free(self.data);
        }
    };

    pub const Info = struct {
        key: Key,
        value: Value,
        allocator: Allocator,

        pub const Key = enum {
            TimeoutTurn,
            TimeoutMatch,
            MaxMemory,
            TimeLeft,
            GameType,
            Rule,
            Evaluate,
            Folder,
        };

        pub const Value = union {
            limit: u32,
            game_type: GameType,
            rule: Rule,
            position: Turn,
            folder: []u8,
        };

        pub fn scanAlloc(scanner: anytype, allocator: Allocator) !Info {
            var buffer: [15]u8 = undefined;
            try scanner.skipWhitespaces();
            const key_string = try scanner.scanUtf8String(buffer[0..]);
            const key: Key = key_dispatch: {
                if (std.mem.eql(u8, key_string, "timeout_turn")) {
                    break :key_dispatch .TimeoutTurn;
                }
                if (std.mem.eql(u8, key_string, "timeout_match")) {
                    break :key_dispatch .TimeoutMatch;
                }
                if (std.mem.eql(u8, key_string, "max_memory")) {
                    break :key_dispatch .MaxMemory;
                }
                if (std.mem.eql(u8, key_string, "time_left")) {
                    break :key_dispatch .TimeLeft;
                }
                if (std.mem.eql(u8, key_string, "game_type")) {
                    break :key_dispatch .GameType;
                }
                if (std.mem.eql(u8, key_string, "rule")) {
                    break :key_dispatch .Rule;
                }
                if (std.mem.eql(u8, key_string, "evaluate")) {
                    break :key_dispatch .Evaluate;
                }
                if (std.mem.eql(u8, key_string, "folder")) {
                    break :key_dispatch .Folder;
                }
                return error.InvalidCommand;
            };
            try scanner.skipWhitespaces();
            const value: Value = value_dispatch: {
                switch (key) {
                    .TimeoutTurn, .TimeoutMatch, .MaxMemory, .TimeLeft => {
                        const limit = try scanner.scan(u32);
                        break :value_dispatch .{ .limit = limit };
                    },
                    .GameType => {
                        const game_type: GameType = switch (try scanner.scan(u2)) {
                            0 => .Human,
                            1 => .Brain,
                            2 => .Tournament,
                            3 => .Network,
                        };
                        break :value_dispatch .{ .game_type = game_type };
                    },
                    .Rule => {
                        const rule = try scanner.scan(u3);
                        break :value_dispatch .{ .rule = .{ .mask = rule } };
                    },
                    .Evaluate => {
                        const position = try scanner.scan(Turn);
                        break :value_dispatch .{ .position = position };
                    },
                    .Folder => {
                        const folder = try scanner.scanUtf8StringAlloc(allocator);
                        break :value_dispatch .{ .folder = folder };
                    },
                }
            };
            return Info{ .key = key, .value = value, .allocator = allocator };
        }

        pub fn deinit(self: Info) void {
            switch (self.key) {
                .Folder => {
                    self.allocator.free(self.value.folder);
                },
                else => {},
            }
        }
    };

    pub fn scanAlloc(scanner: anytype, allocator: Allocator) !Self {
        var buffer: [10]u8 = undefined;
        try scanner.skipWhitespaces();
        const command = try scanner.scanUtf8String(buffer[0..]);
        if (std.mem.eql(u8, command, "START")) {
            const start = try scanner.scan(Start);
            return Self{ .Start = start };
        }
        if (std.mem.eql(u8, command, "TURN")) {
            const turn = try scanner.scan(Turn);
            return Self{ .Turn = turn };
        }
        if (std.mem.eql(u8, command, "BEGIN")) {
            return Self.Begin;
        }
        if (std.mem.eql(u8, command, "BOARD")) {
            const board = try scanner.scanAlloc(Board, allocator);
            return Self{ .Board = board };
        }
        if (std.mem.eql(u8, command, "INFO")) {
            const info = try scanner.scanAlloc(Info, allocator);
            return Self{ .Info = info };
        }
        if (std.mem.eql(u8, command, "END")) {
            return Self.End;
        }
        if (std.mem.eql(u8, command, "ABOUT")) {
            return Self.About;
        }
        if (std.mem.eql(u8, command, "RECTSTART")) {
            const rectstart = try scanner.scan(Turn);
            return Self{ .Rectstart = rectstart };
        }
        if (std.mem.eql(u8, command, "RESTART")) {
            return Self.Restart;
        }
        if (std.mem.eql(u8, command, "TAKEBACK")) {
            const takeback = try scanner.scan(Turn);
            return Self{ .Takeback = takeback };
        }
        if (std.mem.eql(u8, command, "PLAY")) {
            const play = try scanner.scan(Turn);
            return Self{ .Play = play };
        }
        return error.InvalidCommand;
    }

    pub fn deinit(self: Self) void {
        switch (self) {
            .Board => {
                self.Board.deinit();
            },
            .Info => {
                self.Info.deinit();
            },
            else => {},
        }
    }
};

pub const GameManager = struct {
    board: Array(Color, 2),
    timeout_turn: u64 = 30000 * std.time.ns_per_ms,
    timeout_match: u64 = 1000000000 * std.time.ns_per_ms,
    max_memory: u32 = 0,
    time_left: u64 = 1000000000 * std.time.ns_per_ms,
    game_type: GameType = .Brain,
    rule: Rule = .{ .mask = 0 },
    folder: ?[]u8 = null,
    player: Color = .None,
    timestamp: i128,
    brain: *Brain,
    allocator: Allocator,

    const Self = @This();

    pub fn init(width: usize, height: usize, allocator: Allocator) error{ OutOfMemory, TimerUnsupported, UnsupportedSize }!Self {
        if (width != 15 or height != 15) {
            return error.UnsupportedSize;
        }
        var board = try Array(Color, 2).init(allocator, [2]usize{ width, height });
        errdefer board.deinit();
        std.mem.set(Color, board.data, .None);
        var brain = try allocator.create(Brain);
        errdefer allocator.destroy(brain);
        return Self{ .board = board, .timestamp = std.time.nanoTimestamp(), .brain = brain, .allocator = allocator };
    }

    pub fn deinit(self: Self) void {
        self.brain.deinit();
        self.allocator.destroy(self.brain);
        if (self.folder != null) {
            self.allocator.free(self.folder.?);
        }
        self.board.deinit();
    }

    fn reset(self: *Self) void {
        self.time_left = self.timeout_match;
        std.mem.set(Color, self.board.data, .None);
    }

    inline fn timeLap(self: *const Self) u64 {
        return @truncate(u64, @bitCast(u128, std.time.nanoTimestamp() - self.timestamp));
    }

    /// Time left for turn (nanoseconds)
    pub inline fn timeLeft(self: *const Self) u64 {
        return std.math.min(self.time_left, self.timeout_turn) -| self.timeLap();
    }

    // Call brain
    fn play(self: *Self) !void {
        self.timestamp = std.time.nanoTimestamp();
        const position = try self.brain.play();
        response(.Answer, "", .{ position[0], position[1] });
        const lap = self.timeLap();
        self.time_left = self.time_left -| lap;
        self.board.set(position, self.player);
    }

    // Call brain for evaluation
    fn evaluate(self: *Self, x: usize, y: usize) !void {
        if (comptime builtin.mode == .Debug) {
            try self.brain.evaluate(x, y);
        }
    }

    /// Process command sent by Gomocup manager
    pub fn process(self: *Self, command: Command) !void {
        switch (command) {
            .Turn => {
                if (self.player == .None) {
                    self.player = .White;
                    try self.brain.init(self);
                }
                self.board.set(.{ command.Turn.x, command.Turn.y }, if (self.player == .Black) .White else .Black);
                try self.play();
            },
            .Begin => {
                self.player = .Black;
                try self.brain.init(self);
                try self.play();
            },
            .Board => {
                var own_count: usize = 0;
                var opponent_count: usize = 0;
                for (command.Board.data) |datum| {
                    switch (datum.field) {
                        .Own => {
                            own_count += 1;
                        },
                        .Opponent => {
                            opponent_count += 1;
                        },
                        .Winning => {
                            own_count = 0;
                            opponent_count = 0;
                        },
                        else => unreachable,
                    }
                }
                if (self.player == .None) {
                    self.player = if (own_count >= opponent_count) .Black else .White;
                    try self.brain.init(self);
                }
                for (command.Board.data) |datum| {
                    switch (datum.field) {
                        .Own => {
                            self.board.set(.{ datum.x, datum.y }, self.player);
                        },
                        .Opponent => {
                            self.board.set(.{ datum.x, datum.y }, if (self.player == .Black) .White else .Black);
                        },
                        .Winning => {
                            self.reset();
                        },
                        else => unreachable,
                    }
                }
                try self.play();
            },
            .Info => {
                switch (command.Info.key) {
                    .TimeoutTurn => {
                        const limit: u64 = if (command.Info.value.limit != 0) command.Info.value.limit else 30000;
                        self.timeout_turn = limit * std.time.ns_per_ms;
                    },
                    .TimeoutMatch => {
                        const limit: u64 = if (command.Info.value.limit != 0) command.Info.value.limit else 2147483647;
                        self.timeout_match = limit * std.time.ns_per_ms;
                        self.time_left = self.timeout_match;
                    },
                    .MaxMemory => {
                        self.max_memory = command.Info.value.limit;
                    },
                    .TimeLeft => {
                        self.time_left = @as(u64, command.Info.value.limit) * std.time.ns_per_ms;
                    },
                    .GameType => {
                        self.game_type = command.Info.value.game_type;
                    },
                    .Rule => {
                        self.rule = command.Info.value.rule;
                    },
                    .Evaluate => {
                        try self.evaluate(command.Info.value.position.x, command.Info.value.position.y);
                    },
                    .Folder => {
                        self.folder = try self.allocator.dupe(u8, command.Info.value.folder);
                    },
                }
            },
            .About => {
                response(.About, "", .{ "(name)", "(version)", "(author)", "(country)", "(www)", "(email)" });
            },
            .Restart => {
                self.reset();
                response(.Ok, "", .{});
            },
            .Takeback => {
                self.board.set(.{ command.Takeback.x, command.Takeback.y }, .None);
                response(.Ok, "", .{});
            },
            .Play => {
                self.board.set(.{ command.Play.x, command.Play.y }, self.player);
                response(.Answer, "", .{ command.Play.x, command.Play.y });
            },
            else => {
                return error.InvalidCommand;
            },
        }
    }
};

pub const ResponseType = enum {
    Unknown,
    Error,
    Message,
    Debug,
    Suggest,
    Ok,
    Answer,
    About,
};

/// Response to Gomocup manager
pub fn response(comptime level: ResponseType, comptime format: []const u8, args: anytype) void {
    const writer = std.io.getStdOut().writer();
    switch (level) {
        .Unknown => {
            writer.print("UNKNOWN " ++ format ++ "\n", args) catch {};
        },
        .Error => {
            writer.print("ERROR " ++ format ++ "\n", args) catch {};
        },
        .Message => {
            switch (builtin.mode) {
                .Debug, .ReleaseSafe => {
                    writer.print("MESSAGE " ++ format ++ "\n", args) catch {};
                },
                else => {},
            }
        },
        .Debug => {
            switch (builtin.mode) {
                .Debug => {
                    writer.print("DEBUG " ++ format ++ "\n", args) catch {};
                },
                else => {},
            }
        },
        .Suggest => {
            writer.print("SUGGEST {d},{d}\n", args) catch {};
        },
        .Ok => {
            writer.print("OK\n", args) catch {};
        },
        .Answer => {
            writer.print("{d},{d}\n", args) catch {};
        },
        .About => {
            writer.print("name=\"{s}\", version=\"{s}\", author=\"{s}\", country=\"{s}\", www=\"{s}\", email=\"{s}\"\n", args) catch {};
        },
    }
}
