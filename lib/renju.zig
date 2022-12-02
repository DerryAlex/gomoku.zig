const std = @import("std");
const trait = std.meta.trait;
const Child = std.meta.Child;
const Array = @import("array.zig").Array;
const Color = enum { None, Black, White };

pub const opening = [26][3][2]usize{
    // Indirect openings
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 8, 6 }, [_]usize{ 9, 5 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 8, 6 }, [_]usize{ 9, 6 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 8, 6 }, [_]usize{ 9, 7 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 8, 6 }, [_]usize{ 9, 8 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 8, 6 }, [_]usize{ 9, 9 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 8, 6 }, [_]usize{ 8, 7 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 8, 6 }, [_]usize{ 8, 8 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 8, 6 }, [_]usize{ 8, 9 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 8, 6 }, [_]usize{ 7, 8 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 8, 6 }, [_]usize{ 7, 9 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 8, 6 }, [_]usize{ 6, 8 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 8, 6 }, [_]usize{ 6, 9 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 8, 6 }, [_]usize{ 5, 9 } },
    // Direct openings
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 7, 6 }, [_]usize{ 7, 5 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 7, 6 }, [_]usize{ 8, 5 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 7, 6 }, [_]usize{ 9, 5 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 7, 6 }, [_]usize{ 8, 6 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 7, 6 }, [_]usize{ 9, 6 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 7, 6 }, [_]usize{ 8, 7 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 7, 6 }, [_]usize{ 9, 7 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 7, 6 }, [_]usize{ 7, 8 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 7, 6 }, [_]usize{ 8, 8 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 7, 6 }, [_]usize{ 9, 8 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 7, 6 }, [_]usize{ 7, 9 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 7, 6 }, [_]usize{ 8, 9 } },
    [3][2]usize{ [_]usize{ 7, 7 }, [_]usize{ 7, 6 }, [_]usize{ 9, 9 } },
};

const dir = [4][2]isize{ [_]isize{ 1, 0 }, [_]isize{ 0, 1 }, [_]isize{ 1, 1 }, [_]isize{ 1, -1 } };

fn isArray(comptime T: type) bool {
    return trait.hasField("dimension")(Child(T)) and trait.hasField("data")(Child(T));
}

fn isValidCoordinate(board: anytype, x: isize, y: isize) bool {
    if (comptime !isArray(@TypeOf(board))) @compileError("Expect board: *Array(Color, 2)");
    return 0 <= x and x < board.dimension[0] and 0 <= y and y < board.dimension[1];
}

fn countAll(board: anytype, x: usize, y: usize, comptime countFn: *const fn (anytype, usize, usize, comptime_int, comptime_int) usize) usize {
    if (comptime !isArray(@TypeOf(board))) @compileError("Expect board: *Array(Color, 2)");
    var result: usize = 0;
    inline for (dir) |n| {
        const dx = n[0];
        const dy = n[1];
        result += countFn(board, x, y, dx, dy);
    }
    return result;
}

fn count(board: anytype, x: usize, y: usize, comptime dx: comptime_int, comptime dy: comptime_int) usize {
    if (comptime !isArray(@TypeOf(board))) @compileError("Expect board: *Array(Color, 2)");
    var result: usize = 0;
    const color = board.get([2]usize{ x, y });
    var i = @bitCast(isize, x);
    var j = @bitCast(isize, y);
    while (isValidCoordinate(board, i, j) and board.get([2]usize{ @bitCast(usize, i), @bitCast(usize, j) }) == color) {
        result += 1;
        i += dx;
        j += dy;
    }
    i = @bitCast(isize, x) - dx;
    j = @bitCast(isize, y) - dy;
    while (isValidCoordinate(board, i, j) and board.get([2]usize{ @bitCast(usize, i), @bitCast(usize, j) }) == color) {
        result += 1;
        i -= dx;
        j -= dy;
    }
    return result;
}

fn countFour(board: anytype, x: usize, y: usize, comptime dx: comptime_int, comptime dy: comptime_int) usize {
    if (comptime !isArray(@TypeOf(board))) @compileError("Expect board: *Array(Color, 2)");
    var result: usize = 0;
    const color = board.get([2]usize{ x, y });
    var i = @bitCast(isize, x);
    var j = @bitCast(isize, y);
    var flag = false;
    const L0 = count(board, x, y, dx, dy);
    while (isValidCoordinate(board, i, j) and board.get([2]usize{ @bitCast(usize, i), @bitCast(usize, j) }) == color) {
        i += dx;
        j += dy;
    }
    if (isValidCoordinate(board, i, j) and board.get([2]usize{ @bitCast(usize, i), @bitCast(usize, j) }) == .None) {
        var L1: usize = 1;
        if (isValidCoordinate(board, i + dx, j + dy) and board.get([2]usize{ @bitCast(usize, i + dx), @bitCast(usize, j + dy) }) == color) {
            L1 += count(board, @bitCast(usize, i + dx), @bitCast(usize, j + dy), dx, dy);
        }
        if (L0 + L1 == 5) {
            if (L1 == 1) {
                flag = true;
            }
            result += 1;
        }
    }
    i -= dx * (@bitCast(isize, L0) + 1);
    j -= dy * (@bitCast(isize, L0) + 1);
    if (isValidCoordinate(board, i, j) and board.get([2]usize{ @bitCast(usize, i), @bitCast(usize, j) }) == .None) {
        var L1: usize = 1;
        if (isValidCoordinate(board, i - dx, j - dy) and board.get([2]usize{ @bitCast(usize, i - dx), @bitCast(usize, j - dy) }) == color) {
            L1 += count(board, @bitCast(usize, i - dx), @bitCast(usize, j - dy), dx, dy);
        }
        if (L0 + L1 == 5 and (L1 != 1 or !flag)) {
            result += 1;
        }
    }
    return result;
}

fn countStraightFour(board: anytype, x: usize, y: usize, comptime dx: comptime_int, comptime dy: comptime_int) usize {
    if (comptime !isArray(@TypeOf(board))) @compileError("Expect board: *Array(Color, 2)");
    const color = board.get([2]usize{ x, y });
    var i = @bitCast(isize, x);
    var j = @bitCast(isize, y);
    const L0 = count(board, x, y, dx, dy);
    while (isValidCoordinate(board, i, j) and board.get([2]usize{ @bitCast(usize, i), @bitCast(usize, j) }) == color) {
        i += dx;
        j += dy;
    }
    if (L0 == 4 and isValidCoordinate(board, i, j) and board.get([2]usize{ @bitCast(usize, i), @bitCast(usize, j) }) == .None and isValidCoordinate(board, i - dx * (@bitCast(isize, L0) + 1), j - dy * (@bitCast(isize, L0) + 1)) and board.get([2]usize{ @bitCast(usize, i - dx * (@bitCast(isize, L0) + 1)), @bitCast(usize, j - dy * (@bitCast(isize, L0) + 1)) }) == .None and (!isValidCoordinate(board, i + dx, j + dy) or board.get([2]usize{ @bitCast(usize, i + dx), @bitCast(usize, j + dy) }) != color) and (!isValidCoordinate(board, i - dx * (@bitCast(isize, L0) + 2), j - dy * (@bitCast(isize, L0) + 2)) or board.get([2]usize{ @bitCast(usize, i - dx * (@bitCast(isize, L0) + 2)), @bitCast(usize, j - dy * (@bitCast(isize, L0) + 2)) }) != color)) {
        return 1;
    }
    return 0;
}

fn countThree(board: anytype, x: usize, y: usize, comptime dx: comptime_int, comptime dy: comptime_int) usize {
    if (comptime !isArray(@TypeOf(board))) @compileError("Expect board: *Array(Color, 2)");
    var result: usize = 0;
    const color = board.get([2]usize{ x, y });
    var i = @bitCast(isize, x);
    var j = @bitCast(isize, y);
    var flag = false;
    const L0 = count(board, x, y, dx, dy);
    while (isValidCoordinate(board, i, j) and board.get([2]usize{ @bitCast(usize, i), @bitCast(usize, j) }) == color) {
        i += dx;
        j += dy;
    }
    if (isValidCoordinate(board, i, j) and board.get([2]usize{ @bitCast(usize, i), @bitCast(usize, j) }) == .None) {
        var L1: usize = 1;
        if (isValidCoordinate(board, i + dx, j + dy) and board.get([2]usize{ @bitCast(usize, i + dx), @bitCast(usize, j + dy) }) == color) {
            L1 += count(board, @bitCast(usize, i + dx), @bitCast(usize, j + dy), dx, dy);
        }
        if (L0 + L1 == 4) {
            board.set([2]usize{ @bitCast(usize, i), @bitCast(usize, j) }, color);
            if (!checkWin(board, @bitCast(usize, i), @bitCast(usize, j)) and checkLegal(board, @bitCast(usize, i), @bitCast(usize, j)) and countAll(board, @bitCast(usize, i), @bitCast(usize, j), countStraightFour) > 0) {
                if (L1 == 1) {
                    flag = true;
                }
                result += 1;
            }
            board.set([2]usize{ @bitCast(usize, i), @bitCast(usize, j) }, .None);
        }
    }
    i -= dx * (@bitCast(isize, L0) + 1);
    j -= dy * (@bitCast(isize, L0) + 1);
    if (isValidCoordinate(board, i, j) and board.get([2]usize{ @bitCast(usize, i), @bitCast(usize, j) }) == .None) {
        var L1: usize = 1;
        if (isValidCoordinate(board, i - dx, j - dy) and board.get([2]usize{ @bitCast(usize, i - dx), @bitCast(usize, j - dy) }) == color) {
            L1 += count(board, @bitCast(usize, i - dx), @bitCast(usize, j - dy), dx, dy);
        }
        if (L0 + L1 == 4 and (L1 != 1 or !flag)) {
            board.set([2]usize{ @bitCast(usize, i), @bitCast(usize, j) }, color);
            if (!checkWin(board, @bitCast(usize, i), @bitCast(usize, j)) and checkLegal(board, @bitCast(usize, i), @bitCast(usize, j)) and countAll(board, @bitCast(usize, i), @bitCast(usize, j), countStraightFour) > 0) {
                result += 1;
            }
            board.set([2]usize{ @bitCast(usize, i), @bitCast(usize, j) }, .None);
        }
    }
    return result;
}

pub fn checkWin(board: anytype, x: usize, y: usize) bool {
    if (comptime !isArray(@TypeOf(board))) @compileError("Expect board: *Array(Color, 2)");
    const isWhitePlayer = board.get([2]usize{ x, y }) == .White;
    inline for (dir) |n| {
        const dx = n[0];
        const dy = n[1];
        const cnt = count(board, x, y, dx, dy);
        if (cnt == 5 or (isWhitePlayer and cnt > 5)) {
            return true;
        }
    }
    return false;
}

pub fn checkLegal(board: anytype, x: usize, y: usize) bool {
    if (comptime !isArray(@TypeOf(board))) @compileError("Expect board: *Array(Color, 2)");
    const isWhitePlayer = board.get([2]usize{ x, y }) == .White;
    if (isWhitePlayer) {
        return true;
    }
    inline for (dir) |n| {
        const dx = n[0];
        const dy = n[1];
        const cnt = count(board, x, y, dx, dy);
        if (cnt > 5) {
            return false;
        }
    }
    if (countAll(board, x, y, countFour) >= 2 or countAll(board, x, y, countThree) >= 2) {
        return false;
    }
    return true;
}

// https://www.renju.net/advanced/
test "renju/forbidden moves" {
    const allocator = std.testing.allocator;
    var board = try Array(Color, 2).init(allocator, [2]usize{ 15, 15 });
    std.mem.set(Color, board.data, .None);
    defer board.deinit();
    {
        board.set([2]usize{ 4, 2 }, .Black);
        board.set([2]usize{ 2, 3 }, .Black);
        board.set([2]usize{ 4, 3 }, .Black);
        board.set([2]usize{ 1, 4 }, .Black);
        board.set([2]usize{ 4, 4 }, .Black);
        board.set([2]usize{ 0, 5 }, .Black);
        board.set([2]usize{ 4, 5 }, .White);
        board.set([2]usize{ 4, 1 }, .Black);
        try std.testing.expectEqual(checkLegal(&board, 4, 1), false);
        board.set([2]usize{ 4, 1 }, .None);
    }
    {
        board.set([2]usize{ 4, 7 }, .Black);
        board.set([2]usize{ 5, 7 }, .Black);
        board.set([2]usize{ 7, 7 }, .Black);
        board.set([2]usize{ 8, 7 }, .Black);
        board.set([2]usize{ 9, 7 }, .Black);
        board.set([2]usize{ 6, 7 }, .Black);
        try std.testing.expectEqual(checkLegal(&board, 6, 7), false);
        board.set([2]usize{ 6, 7 }, .None);
    }
    {
        board.set([2]usize{ 1, 11 }, .Black);
        board.set([2]usize{ 1, 12 }, .Black);
        board.set([2]usize{ 3, 12 }, .Black);
        board.set([2]usize{ 3, 13 }, .Black);
        board.set([2]usize{ 2, 12 }, .Black);
        try std.testing.expectEqual(checkLegal(&board, 2, 12), true);
        board.set([2]usize{ 2, 12 }, .None);
    }
    {
        board.set([2]usize{ 10, 11 }, .Black);
        board.set([2]usize{ 11, 11 }, .Black);
        board.set([2]usize{ 9, 12 }, .Black);
        board.set([2]usize{ 11, 12 }, .Black);
        board.set([2]usize{ 11, 10 }, .Black);
        try std.testing.expectEqual(checkLegal(&board, 11, 10), false);
        board.set([2]usize{ 11, 10 }, .None);
    }
}

test "renju/unclear situation" {
    const allocator = std.testing.allocator;
    var board = try Array(Color, 2).init(allocator, [2]usize{ 15, 15 });
    std.mem.set(Color, board.data, .None);
    defer board.deinit();
    {
        board.set([2]usize{ 12, 2 }, .Black);
        board.set([2]usize{ 6, 5 }, .Black);
        board.set([2]usize{ 7, 5 }, .Black);
        board.set([2]usize{ 8, 6 }, .Black);
        board.set([2]usize{ 7, 7 }, .Black);
        board.set([2]usize{ 5, 9 }, .White);
        board.set([2]usize{ 9, 5 }, .Black);
        try std.testing.expectEqual(checkLegal(&board, 9, 5), true);
        board.set([2]usize{ 9, 5 }, .None);
    }
}

test "renju/example questions" {
    const allocator = std.testing.allocator;
    var board = try Array(Color, 2).init(allocator, [2]usize{ 15, 15 });
    std.mem.set(Color, board.data, .None);
    defer board.deinit();
    {
        board.set([2]usize{ 4, 2 }, .Black);
        board.set([2]usize{ 0, 3 }, .Black);
        board.set([2]usize{ 4, 3 }, .Black);
        board.set([2]usize{ 5, 3 }, .Black);
        board.set([2]usize{ 8, 3 }, .Black);
        board.set([2]usize{ 2, 4 }, .Black);
        board.set([2]usize{ 3, 3 }, .Black);
        try std.testing.expectEqual(checkLegal(&board, 3, 3), true);
        board.set([2]usize{ 3, 3 }, .None);
    }
    {
        board.set([2]usize{ 14, 1 }, .Black);
        board.set([2]usize{ 11, 4 }, .Black);
        board.set([2]usize{ 13, 4 }, .Black);
        board.set([2]usize{ 10, 5 }, .Black);
        board.set([2]usize{ 13, 5 }, .Black);
        board.set([2]usize{ 9, 6 }, .Black);
        board.set([2]usize{ 13, 6 }, .Black);
        board.set([2]usize{ 8, 7 }, .White);
        board.set([2]usize{ 13, 7 }, .White);
        board.set([2]usize{ 13, 2 }, .Black);
        try std.testing.expectEqual(checkLegal(&board, 13, 2), true);
        board.set([2]usize{ 13, 2 }, .None);
    }
    {
        board.set([2]usize{ 2, 10 }, .Black);
        board.set([2]usize{ 2, 11 }, .Black);
        board.set([2]usize{ 5, 11 }, .Black);
        board.set([2]usize{ 4, 12 }, .Black);
        board.set([2]usize{ 6, 14 }, .White);
        board.set([2]usize{ 3, 11 }, .Black);
        try std.testing.expectEqual(checkLegal(&board, 3, 11), false);
        board.set([2]usize{ 3, 11 }, .None);
    }
    {
        board.set([2]usize{ 10, 10 }, .White);
        board.set([2]usize{ 11, 10 }, .Black);
        board.set([2]usize{ 12, 10 }, .White);
        board.set([2]usize{ 10, 11 }, .White);
        board.set([2]usize{ 12, 11 }, .White);
        board.set([2]usize{ 10, 12 }, .Black);
        board.set([2]usize{ 12, 12 }, .Black);
        board.set([2]usize{ 9, 13 }, .White);
        board.set([2]usize{ 10, 13 }, .White);
        board.set([2]usize{ 11, 13 }, .Black);
        board.set([2]usize{ 12, 13 }, .White);
        board.set([2]usize{ 13, 13 }, .White);
        board.set([2]usize{ 10, 14 }, .White);
        board.set([2]usize{ 12, 14 }, .White);
        board.set([2]usize{ 11, 12 }, .Black);
        try std.testing.expectEqual(checkLegal(&board, 11, 12), false);
        board.set([2]usize{ 11, 12 }, .None);
    }
}

test "renju/confusing situation" {
    const allocator = std.testing.allocator;
    var board = try Array(Color, 2).init(allocator, [2]usize{ 15, 15 });
    std.mem.set(Color, board.data, .None);
    defer board.deinit();
    {
        board.set([2]usize{ 6, 3 }, .White);
        board.set([2]usize{ 7, 4 }, .White);
        board.set([2]usize{ 8, 5 }, .White);
        board.set([2]usize{ 8, 6 }, .Black);
        board.set([2]usize{ 10, 6 }, .Black);
        board.set([2]usize{ 7, 7 }, .Black);
        board.set([2]usize{ 8, 7 }, .White);
        board.set([2]usize{ 9, 7 }, .Black);
        board.set([2]usize{ 10, 7 }, .White);
        board.set([2]usize{ 11, 7 }, .Black);
        board.set([2]usize{ 6, 8 }, .White);
        board.set([2]usize{ 7, 8 }, .Black);
        board.set([2]usize{ 8, 8 }, .White);
        board.set([2]usize{ 9, 8 }, .Black);
        board.set([2]usize{ 10, 8 }, .White);
        board.set([2]usize{ 11, 8 }, .Black);
        board.set([2]usize{ 12, 8 }, .White);
        board.set([2]usize{ 7, 9 }, .Black);
        board.set([2]usize{ 11, 9 }, .Black);
        board.set([2]usize{ 7, 10 }, .White);
        board.set([2]usize{ 11, 10 }, .White);
        board.set([2]usize{ 9, 6 }, .Black);
        try std.testing.expectEqual(checkLegal(&board, 9, 6), true);
        board.set([2]usize{ 9, 6 }, .None);
    }
}

test "renju/real game" {
    const allocator = std.testing.allocator;
    var board = try Array(Color, 2).init(allocator, [2]usize{ 15, 15 });
    std.mem.set(Color, board.data, .None);
    defer board.deinit();
    {
        board.set([2]usize{ 7, 7 }, .Black);
        board.set([2]usize{ 7, 6 }, .White);
        board.set([2]usize{ 9, 5 }, .Black);
        board.set([2]usize{ 8, 6 }, .White);
        board.set([2]usize{ 8, 4 }, .Black);
        board.set([2]usize{ 10, 6 }, .White);
        board.set([2]usize{ 6, 6 }, .Black);
        board.set([2]usize{ 7, 5 }, .White);
        board.set([2]usize{ 6, 5 }, .Black);
        board.set([2]usize{ 6, 4 }, .White);
        board.set([2]usize{ 9, 7 }, .Black);
        board.set([2]usize{ 8, 7 }, .White);
        board.set([2]usize{ 8, 8 }, .Black);
        board.set([2]usize{ 5, 5 }, .White);
        board.set([2]usize{ 5, 3 }, .Black);
        board.set([2]usize{ 9, 8 }, .White);
        board.set([2]usize{ 10, 9 }, .Black);
        board.set([2]usize{ 8, 9 }, .White);
        board.set([2]usize{ 10, 7 }, .Black);
        board.set([2]usize{ 7, 3 }, .White);
        board.set([2]usize{ 8, 2 }, .Black);
        board.set([2]usize{ 6, 7 }, .White);
        board.set([2]usize{ 8, 3 }, .Black);
        board.set([2]usize{ 11, 6 }, .White);
        board.set([2]usize{ 9, 6 }, .Black);
        board.set([2]usize{ 7, 2 }, .White);
        board.set([2]usize{ 7, 4 }, .Black);
        try std.testing.expectEqual(checkLegal(&board, 7, 4), true);
        board.set([2]usize{ 7, 4 }, .None);
    }
}

test "renju/complex forks" {
    const allocator = std.testing.allocator;
    var board = try Array(Color, 2).init(allocator, [2]usize{ 15, 15 });
    std.mem.set(Color, board.data, .None);
    defer board.deinit();
    {
        board.set([2]usize{ 1, 1 }, .Black);
        board.set([2]usize{ 2, 3 }, .Black);
        board.set([2]usize{ 4, 3 }, .Black);
        board.set([2]usize{ 2, 4 }, .Black);
        board.set([2]usize{ 3, 4 }, .White);
        board.set([2]usize{ 4, 4 }, .Black);
        board.set([2]usize{ 1, 5 }, .Black);
        board.set([2]usize{ 2, 5 }, .White);
        board.set([2]usize{ 4, 5 }, .White);
        board.set([2]usize{ 3, 3 }, .Black);
        try std.testing.expectEqual(checkLegal(&board, 3, 3), false);
        board.set([2]usize{ 3, 3 }, .None);
    }
    {
        board.set([2]usize{ 11, 0 }, .White);
        board.set([2]usize{ 12, 0 }, .Black);
        board.set([2]usize{ 13, 0 }, .White);
        board.set([2]usize{ 10, 1 }, .Black);
        board.set([2]usize{ 11, 1 }, .White);
        board.set([2]usize{ 12, 1 }, .Black);
        board.set([2]usize{ 13, 1 }, .White);
        board.set([2]usize{ 14, 1 }, .Black);
        board.set([2]usize{ 10, 2 }, .White);
        board.set([2]usize{ 11, 2 }, .Black);
        board.set([2]usize{ 12, 2 }, .Black);
        board.set([2]usize{ 13, 2 }, .Black);
        board.set([2]usize{ 14, 2 }, .White);
        board.set([2]usize{ 11, 4 }, .Black);
        board.set([2]usize{ 14, 5 }, .Black);
        board.set([2]usize{ 12, 3 }, .Black);
        try std.testing.expectEqual(checkLegal(&board, 12, 3), false);
        board.set([2]usize{ 12, 3 }, .None);
    }
    {
        board.set([2]usize{ 1, 10 }, .Black);
        board.set([2]usize{ 2, 10 }, .Black);
        board.set([2]usize{ 4, 10 }, .Black);
        board.set([2]usize{ 5, 10 }, .White);
        board.set([2]usize{ 2, 11 }, .White);
        board.set([2]usize{ 3, 11 }, .Black);
        board.set([2]usize{ 4, 11 }, .Black);
        board.set([2]usize{ 5, 11 }, .White);
        board.set([2]usize{ 2, 12 }, .White);
        board.set([2]usize{ 3, 12 }, .Black);
        board.set([2]usize{ 4, 12 }, .White);
        board.set([2]usize{ 5, 12 }, .Black);
        board.set([2]usize{ 3, 13 }, .Black);
        board.set([2]usize{ 3, 14 }, .White);
        board.set([2]usize{ 3, 10 }, .Black);
        try std.testing.expectEqual(checkLegal(&board, 3, 10), false);
        board.set([2]usize{ 3, 10 }, .None);
    }
    {
        board.set([2]usize{ 12, 9 }, .Black);
        board.set([2]usize{ 10, 10 }, .Black);
        board.set([2]usize{ 13, 10 }, .Black);
        board.set([2]usize{ 10, 11 }, .White);
        board.set([2]usize{ 11, 11 }, .Black);
        board.set([2]usize{ 12, 11 }, .Black);
        board.set([2]usize{ 13, 11 }, .White);
        board.set([2]usize{ 14, 11 }, .White);
        board.set([2]usize{ 10, 12 }, .Black);
        board.set([2]usize{ 11, 12 }, .White);
        board.set([2]usize{ 9, 13 }, .Black);
        board.set([2]usize{ 8, 14 }, .White);
        board.set([2]usize{ 12, 10 }, .Black);
        try std.testing.expectEqual(checkLegal(&board, 12, 10), false);
        board.set([2]usize{ 12, 10 }, .None);
    }
}
