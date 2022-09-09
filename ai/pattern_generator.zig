const std = @import("std");
const Pattern = @import("pattern.zig").Pattern;
const patterns = @import("pattern.zig").patterns;

const score: [patterns]i32 = [_]i32{ 0, 1024, 1024, 256, 32, 32, 8, 4, 1 };

var pattern: [256][256][2]Pattern = [_][256][2]Pattern{[_][2]Pattern{[_]Pattern{.None} ** 2} ** 256} ** 256;
var pattern_score: [patterns][patterns][patterns][patterns][2]i32 = [_][patterns][patterns][patterns][2]i32{[_][patterns][patterns][2]i32{[_][patterns][2]i32{[_][2]i32{[_]i32{0} ** 2} ** patterns} ** patterns} ** patterns} ** patterns;

// Bit representation (L4,L3,L2,L1,R1,R2,R3,R4)
fn checkFive(self: u8, opponent: u8) Pattern {
    var count: usize = 1;
    var i: u8 = 8;
    while (i != 0) : (i >>= 1) {
        if (self & i != 0 and opponent & i == 0) {
            count += 1;
        } else {
            break;
        }
    }
    i = 16;
    while (i != 0) : (i <<= 1) {
        if (self & i != 0 and opponent & i == 0) {
            count += 1;
        } else {
            break;
        }
    }
    if (count > 5) {
        return .Overline;
    }
    if (count == 5) {
        return .Five;
    }
    return .None;
}

fn checkFour(self: u8, opponent: u8, is_black: bool) Pattern {
    var count: usize = 0;
    var i: u8 = 1;
    while (i != 0) : (i <<= 1) {
        if (self & i == 0 and opponent & i == 0) {
            if (pattern[self | i][opponent][@boolToInt(is_black)] == .Five) {
                count += 1;
            }
            if (pattern[self | i][opponent][@boolToInt(is_black)] == .Overline and !is_black) {
                count += 1;
            }
        }
    }
    if (count >= 2) {
        return .Four;
    }
    if (count == 1) {
        return .FourSleep;
    }
    return .None;
}

fn checkPattern(self: u8, opponent: u8, is_black: bool, pattern_type: Pattern) bool {
    var i: u8 = 1;
    while (i != 0) : (i <<= 1) {
        if (self & i == 0 and opponent & i == 0 and pattern[self | i][opponent][@boolToInt(is_black)] == pattern_type) {
            return true;
        }
    }
    return false;
}

fn generatePattern() void {
    {
        var i: usize = 0;
        while (i < 256) : (i += 1) {
            var j: usize = 0;
            while (j < 256) : (j += 1) {
                pattern[i][j][0] = checkFive(@truncate(u8, i), @truncate(u8, j));
                pattern[i][j][1] = checkFive(@truncate(u8, i), @truncate(u8, j));
            }
        }
    }
    {
        var i: usize = 0;
        while (i < 256) : (i += 1) {
            var j: usize = 0;
            while (j < 256) : (j += 1) {
                if (pattern[i][j][0] == .None) {
                    pattern[i][j][0] = checkFour(@truncate(u8, i), @truncate(u8, j), false);
                }
                if (pattern[i][j][1] == .None) {
                    pattern[i][j][1] = checkFour(@truncate(u8, i), @truncate(u8, j), true);
                }
            }
        }
    }
    var pat = @enumToInt(Pattern.Three);
    while (pat < patterns) : (pat += 1) {
        var i: usize = 0;
        while (i < 256) : (i += 1) {
            var j: usize = 0;
            while (j < 256) : (j += 1) {
                if (pattern[i][j][0] == .None and checkPattern(@truncate(u8, i), @truncate(u8, j), false, @intToEnum(Pattern, pat - 2))) {
                    pattern[i][j][0] = @intToEnum(Pattern, pat);
                }
                if (pattern[i][j][1] == .None and checkPattern(@truncate(u8, i), @truncate(u8, j), true, @intToEnum(Pattern, pat - 2))) {
                    pattern[i][j][1] = @intToEnum(Pattern, pat);
                }
            }
        }
    }
}

// Fast evaluation in union jack area
// NOTE: false forbidden moves are not handled correctly
fn generatePatternScore() void {
    var temp_count: [patterns]usize = [_]usize{0} ** patterns;
    var p0: usize = 0;
    while (p0 < patterns) : (p0 += 1) {
        temp_count[p0] += 1;
        var p1: usize = 0;
        while (p1 < patterns) : (p1 += 1) {
            temp_count[p1] += 1;
            var p2: usize = 0;
            while (p2 < patterns) : (p2 += 1) {
                temp_count[p2] += 1;
                var p3: usize = 0;
                while (p3 < patterns) : (p3 += 1) {
                    temp_count[p3] += 1;

                    if (temp_count[@enumToInt(Pattern.Five)] > 0 or temp_count[@enumToInt(Pattern.Overline)] > 0) {
                        pattern_score[p0][p1][p2][p3][0] = 100_000;
                        pattern_score[p0][p1][p2][p3][1] = 100_000;
                    } else if (temp_count[@enumToInt(Pattern.Four)] > 0 or temp_count[@enumToInt(Pattern.FourSleep)] >= 2) {
                        pattern_score[p0][p1][p2][p3][0] = 45_000;
                        pattern_score[p0][p1][p2][p3][1] = 45_000;
                    } else if (temp_count[@enumToInt(Pattern.FourSleep)] > 0 and temp_count[@enumToInt(Pattern.Three)] > 0) {
                        pattern_score[p0][p1][p2][p3][0] = 20_000;
                        pattern_score[p0][p1][p2][p3][1] = 20_000;
                    } else if (temp_count[@enumToInt(Pattern.Three)] >= 2) {
                        pattern_score[p0][p1][p2][p3][0] = 10_000;
                        pattern_score[p0][p1][p2][p3][1] = 10_000;
                    }

                    if (temp_count[@enumToInt(Pattern.Five)] == 0 and (temp_count[@enumToInt(Pattern.Overline)] > 0 or temp_count[@enumToInt(Pattern.Four)] + temp_count[@enumToInt(Pattern.FourSleep)] >= 2 or temp_count[@enumToInt(Pattern.Three)] >= 2)) {
                        pattern_score[p0][p1][p2][p3][1] = -110_000;
                    }

                    pattern_score[p0][p1][p2][p3][0] += score[p0] + score[p1] + score[p2] + score[p3];
                    pattern_score[p0][p1][p2][p3][1] += score[p0] + score[p1] + score[p2] + score[p3];

                    temp_count[p3] -= 1;
                }
                temp_count[p2] -= 1;
            }
            temp_count[p1] -= 1;
        }
        temp_count[p0] -= 1;
    }
}

pub fn main() !void {
    const path = std.fs.cwd();
    const score_bin_file = try path.createFile("score.bin", .{});
    defer score_bin_file.close();
    const pattern_bin_file = try path.createFile("pattern.bin", .{});
    defer pattern_bin_file.close();
    const score_bin_writer = score_bin_file.writer();
    const pattern_bin_writer = pattern_bin_file.writer();

    generatePatternScore();
    for (pattern_score) |arr1| {
        for (arr1) |arr2| {
            for (arr2) |arr3| {
                for (arr3) |arr4| {
                    for (arr4) |val| {
                        const bytes: u32 = @bitCast(u32, val);
                        const byte0: u8 = @truncate(u8, bytes & 0xff);
                        const byte1: u8 = @truncate(u8, (bytes & 0xff00) >> 8);
                        const byte2: u8 = @truncate(u8, (bytes & 0xff_0000) >> 16);
                        const byte3: u8 = @truncate(u8, (bytes & 0xff00_0000) >> 24);
                        try score_bin_writer.print("{c}{c}{c}{c}", .{ byte0, byte1, byte2, byte3 });
                    }
                }
            }
        }
    }
    generatePattern();
    for (pattern) |arr1| {
        for (arr1) |arr2| {
            const byte: u8 = @enumToInt(arr2[0]) | (@as(u8, @enumToInt(arr2[1])) << 4);
            try pattern_bin_writer.print("{c}", .{byte});
        }
    }
}
