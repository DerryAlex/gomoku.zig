const std = @import("std");
const root = @import("root");
const Allocator = std.mem.Allocator;
const Array = root.lib.array.Array;
const protocol = root.protocol;
const GameManager = protocol.GameManager;
const response = protocol.response;
const Nnue = @import("nnue.zig").Nnue;
const pattern = @import("pattern.zig");
const getPattern = pattern.getPattern;
const getScore = pattern.getScore;

pub const Color = enum {
    None,
    Black,
    White,
    Out,
};

const dir = [4][2]isize{ [_]isize{ 1, 0 }, [_]isize{ 0, 1 }, [_]isize{ 1, 1 }, [_]isize{ 1, -1 } };

pub const Board = struct {
    map: Array(Color, 2),
    bit_map: Array(u8, 4),
    score: Array(i32, 3),

    const Self = @This();

    pub fn init(width: usize, height: usize, allocator: Allocator) error{OutOfMemory}!Self {
        var map = try Array(Color, 2).init(allocator, .{ width + 8, height + 8 });
        errdefer map.deinit();
        std.mem.set(Color, map.data, .None);
        var bit_map = try Array(u8, 4).init(allocator, .{ width + 8, height + 8, 2, 4 });
        errdefer bit_map.deinit();
        std.mem.set(u8, bit_map.data, 0);
        var score = try Array(i32, 3).init(allocator, .{ width + 8, height + 8, 2 });
        errdefer allocator.free(score);
        std.mem.set(i32, score.data, 0);
        var i: isize = 0;
        while (i < width + 8) : (i += 1) {
            var j: isize = 0;
            while (j < height + 8) : (j += 1) {
                if (4 <= i and i < width + 4 and 4 <= j and j < height + 4) {
                    continue;
                }
                map.set(.{ @bitCast(usize, i), @bitCast(usize, j) }, .Out);
                inline for (dir) |n, d| {
                    const dx = n[0];
                    const dy = n[1];
                    var k: u3 = 1;
                    while (k <= 4) : (k += 1) {
                        if (i - k * dx < 0 or i - k * dx >= width + 8 or j - k * dy < 0 or j - k * dy >= height + 8) {
                            continue;
                        }
                        bit_map.set(.{ @bitCast(usize, i - k * dx), @bitCast(usize, j - k * dy), 0, d }, (@as(u8, 1) << (4 - k)) | bit_map.get(.{ @bitCast(usize, i - k * dx), @bitCast(usize, j - k * dy), 0, d }));
                        bit_map.set(.{ @bitCast(usize, i - k * dx), @bitCast(usize, j - k * dy), 1, d }, (@as(u8, 1) << (4 - k)) | bit_map.get(.{ @bitCast(usize, i - k * dx), @bitCast(usize, j - k * dy), 1, d }));
                    }
                    k = 1;
                    while (k <= 4) : (k += 1) {
                        if (i + k * dx < 0 or i + k * dx >= width + 8 or j + k * dy < 0 or j + k * dy >= height + 8) {
                            continue;
                        }
                        bit_map.set(.{ @bitCast(usize, i + k * dx), @bitCast(usize, j + k * dy), 0, d }, (@as(u8, 1) << (3 + k)) | bit_map.get(.{ @bitCast(usize, i + k * dx), @bitCast(usize, j + k * dy), 0, d }));
                        bit_map.set(.{ @bitCast(usize, i + k * dx), @bitCast(usize, j + k * dy), 1, d }, (@as(u8, 1) << (3 + k)) | bit_map.get(.{ @bitCast(usize, i + k * dx), @bitCast(usize, j + k * dy), 1, d }));
                    }
                }
            }
        }
        return Self{ .map = map, .bit_map = bit_map, .score = score };
    }

    pub fn deinit(self: Self) void {
        self.score.deinit();
        self.bit_map.deinit();
        self.map.deinit();
    }

    pub fn get(self: *const Self, index: [2]usize) Color {
        return self.map.get(.{ index[0] + 4, index[1] + 4 });
    }

    fn getBits(self: *const Self, x: usize, y: usize) [2][4]u8 {
        var bits: [2][4]u8 = undefined;
        comptime var p = 0;
        inline while (p < 2) : (p += 1) {
            comptime var d = 0;
            inline while (d < 4) : (d += 1) {
                bits[p][d] = self.bit_map.get(.{ x, y, p, d });
            }
        }
        return bits;
    }

    pub fn update(self: *Self, index: [2]usize, color: Color) void {
        const x = @bitCast(isize, index[0] + 4);
        const y = @bitCast(isize, index[1] + 4);
        const old_color = self.map.get(.{ @bitCast(usize, x), @bitCast(usize, y) });
        self.map.set(.{ @bitCast(usize, x), @bitCast(usize, y) }, color);
        inline for (dir) |n, d| {
            const dx = n[0];
            const dy = n[1];
            var k: u3 = 1;
            while (k <= 4) : (k += 1) {
                self.bit_map.set(.{ @bitCast(usize, x - k * dx), @bitCast(usize, y - k * dy), 0, d }, ~(@as(u8, @boolToInt(old_color == .White)) << (4 - k)) & self.bit_map.get(.{ @bitCast(usize, x - k * dx), @bitCast(usize, y - k * dy), 0, d }));
                self.bit_map.set(.{ @bitCast(usize, x - k * dx), @bitCast(usize, y - k * dy), 1, d }, ~(@as(u8, @boolToInt(old_color == .Black)) << (4 - k)) & self.bit_map.get(.{ @bitCast(usize, x - k * dx), @bitCast(usize, y - k * dy), 1, d }));
                self.bit_map.set(.{ @bitCast(usize, x - k * dx), @bitCast(usize, y - k * dy), 0, d }, (@as(u8, @boolToInt(color == .White)) << (4 - k)) | self.bit_map.get(.{ @bitCast(usize, x - k * dx), @bitCast(usize, y - k * dy), 0, d }));
                self.bit_map.set(.{ @bitCast(usize, x - k * dx), @bitCast(usize, y - k * dy), 1, d }, (@as(u8, @boolToInt(color == .Black)) << (4 - k)) | self.bit_map.get(.{ @bitCast(usize, x - k * dx), @bitCast(usize, y - k * dy), 1, d }));
                const bits = self.getBits(@bitCast(usize, x - k * dx), @bitCast(usize, y - k * dy));
                self.score.set(.{ @bitCast(usize, x - k * dx), @bitCast(usize, y - k * dy), 0 }, getScore(bits, false));
                self.score.set(.{ @bitCast(usize, x - k * dx), @bitCast(usize, y - k * dy), 1 }, getScore(bits, true));
            }
            k = 1;
            while (k <= 4) : (k += 1) {
                self.bit_map.set(.{ @bitCast(usize, x + k * dx), @bitCast(usize, y + k * dy), 0, d }, ~(@as(u8, @boolToInt(old_color == .White)) << (3 + k)) & self.bit_map.get(.{ @bitCast(usize, x + k * dx), @bitCast(usize, y + k * dy), 0, d }));
                self.bit_map.set(.{ @bitCast(usize, x + k * dx), @bitCast(usize, y + k * dy), 1, d }, ~(@as(u8, @boolToInt(old_color == .Black)) << (3 + k)) & self.bit_map.get(.{ @bitCast(usize, x + k * dx), @bitCast(usize, y + k * dy), 1, d }));
                self.bit_map.set(.{ @bitCast(usize, x + k * dx), @bitCast(usize, y + k * dy), 0, d }, (@as(u8, @boolToInt(color == .White)) << (3 + k)) | self.bit_map.get(.{ @bitCast(usize, x + k * dx), @bitCast(usize, y + k * dy), 0, d }));
                self.bit_map.set(.{ @bitCast(usize, x + k * dx), @bitCast(usize, y + k * dy), 1, d }, (@as(u8, @boolToInt(color == .Black)) << (3 + k)) | self.bit_map.get(.{ @bitCast(usize, x + k * dx), @bitCast(usize, y + k * dy), 1, d }));
                const bits = self.getBits(@bitCast(usize, x + k * dx), @bitCast(usize, y + k * dy));
                self.score.set(.{ @bitCast(usize, x + k * dx), @bitCast(usize, y + k * dy), 0 }, getScore(bits, false));
                self.score.set(.{ @bitCast(usize, x + k * dx), @bitCast(usize, y + k * dy), 1 }, getScore(bits, true));
            }
        }
    }

    pub fn evaluate(self: *const Self, x: usize, y: usize, is_black: bool) i32 {
        return self.score.get(.{ x + 4, y + 4, @boolToInt(is_black) });
    }

    pub fn isFourSleep(self: *const Self, x: usize, y: usize, is_black: bool) bool {
        const color = @boolToInt(is_black);
        const bits = self.getBits(x + 4, y + 4);
        comptime var d = 0;
        inline while (d < 4) : (d += 1) {
            const pat = getPattern(bits[color][d], bits[1 - color][d], is_black);
            if (pat == .Four or pat == .FourSleep) {
                return true;
            }
        }
        return false;
    }

    pub fn isThree(self: *const Self, x: usize, y: usize, is_black: bool) bool {
        const color = @boolToInt(is_black);
        const bits = self.getBits(x + 4, y + 4);
        comptime var d = 0;
        inline while (d < 4) : (d += 1) {
            const pat = getPattern(bits[color][d], bits[1 - color][d], is_black);
            if (pat == .Three) {
                return true;
            }
        }
        return false;
    }

    pub fn display(self: *const Self) void {
        var buf: [256]u8 = undefined;
        var i: usize = 0;
        while (i < self.map.dimension[0] - 8) : (i += 1) {
            var j: usize = 0;
            while (j < self.map.dimension[0] - 8) : (j += 1) {
                buf[j] = switch (self.get(.{ i, j })) {
                    .None => '.',
                    .Black => 'x',
                    .White => 'o',
                    else => unreachable,
                };
            }
            response(.Message, "{s}", .{buf[0..j]});
        }
    }
};
