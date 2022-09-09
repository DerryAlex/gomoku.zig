pub const Pattern = enum(u4) {
    None,
    Overline,
    Five,
    Four,
    FourSleep,
    Three,
    ThreeSleep,
    Two,
    TwoSleep,
};
pub const patterns = @enumToInt(Pattern.TwoSleep) + 1;

// Comptime generation is quite slow, precompiled binary is used
const pattern = @embedFile("pattern.bin");
const pattern_score = @embedFile("score.bin");

pub fn getPattern(self: u8, opponent: u8, is_black: bool) Pattern {
    const index = @as(usize, self) * 256 + @as(usize, opponent);
    const byte = pattern[index];
    const raw = if (is_black) ((byte & 0xf0) >> 4) else (byte & 0xf);
    return @intToEnum(Pattern, raw);
}

pub fn getPatternScore(p0: Pattern, p1: Pattern, p2: Pattern, p3: Pattern, is_black: bool) i32 {
    const p0_int: usize = @enumToInt(p0);
    const p1_int: usize = @enumToInt(p1);
    const p2_int: usize = @enumToInt(p2);
    const p3_int: usize = @enumToInt(p3);
    const array_index = (((p0_int * patterns + p1_int) * patterns + p2_int) * patterns + p3_int) * 2 + @boolToInt(is_black);
    const index = array_index * @sizeOf(i32);
    const raw = (@as(u32, pattern_score[index + 3]) << 24) | (@as(u32, pattern_score[index + 2]) << 16) | (@as(u32, pattern_score[index + 1]) << 8) | @as(u32, pattern_score[index]);
    return @bitCast(i32, raw);
}

pub fn getScore(bits: [2][4]u8, is_black: bool) i32 {
    const player = @boolToInt(is_black);
    const p0 = getPattern(bits[player][0], bits[1 - player][0], is_black);
    const p1 = getPattern(bits[player][1], bits[1 - player][1], is_black);
    const p2 = getPattern(bits[player][2], bits[1 - player][2], is_black);
    const p3 = getPattern(bits[player][3], bits[1 - player][3], is_black);
    return getPatternScore(p0, p1, p2, p3, is_black);
}
