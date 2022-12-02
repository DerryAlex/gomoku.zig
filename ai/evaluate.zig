const Brain = @import("../ai.zig").Brain;

pub fn evaluateAll(brain: *Brain) i32 {
    if (false) { // Disable NNUE
        return evaluateAllNnue(brain);
    } else {
        return evaluateAllClassical(brain);
    }
}

pub fn evaluateAllClassical(brain: *const Brain) i32 {
    var result: i32 = 0;
    var i: usize = 0;
    while (i < brain.manager.board.dimension[0]) : (i += 1) {
        var j: usize = 0;
        while (j < brain.manager.board.dimension[1]) : (j += 1) {
            if (brain.board.get(.{ i, j }) == .None) {
                result += brain.board.evaluate(i, j, true);
                result -= brain.board.evaluate(i, j, false);
                if (brain.board.evaluate(i, j, true) >= 100_000) return 100_000_000;
                if (brain.board.evaluate(i, j, false) >= 100_000) return -100_000_000;
            }
        }
    }
    return result;
}

pub fn evaluateAllNnue(brain: *Brain) i32 {
    return brain.nnue.evaluate(&brain.board);
}
