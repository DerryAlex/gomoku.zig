const std = @import("std");
const root = @import("root");
const sort = std.sort.sort;
const response = root.protocol.response;
const Brain = @import("../ai.zig").Brain;
const evaluateAll = @import("evaluate.zig").evaluateAll;
const vct = @import("vct.zig");
const vcfSolver = vct.vcfSolver;
const vctSolver = vct.vctSolver;
const getOptimal = vct.getOptimal;

const vcf_depth_limit = 20;
const vct_depth_limit = 12;
const vcf_time_limit = 1 * std.time.ns_per_s;
const vct_time_limit = 1 * std.time.ns_per_s;
const vct_defend_depth_limit = 6;
const vct_defend_time_limit = 500_000;

const search_depth_limit_default = 2;
const search_width_limit_default = 8;
const search_terminate_value = 123_456_789;
const search_win_threshold = 100_000_000;
var search_depth_limit: usize = undefined;
var search_width_limit: usize = undefined;

var brain: *Brain = undefined;
var optimal: [2]usize = undefined;
var best: [2]usize = undefined;

pub inline fn isTimeOut() bool {
    return brain.manager.timeLeft() <= 1000;
}

pub fn search(arg_brain: *Brain) error{ OutOfMemory, TimeOut }![2]usize {
    brain = arg_brain;
    const is_black = brain.manager.player == .Black;
    if (0 < try vcfSolver(vcf_time_limit, vcf_depth_limit, is_black, brain)) {
        return getOptimal();
    }
    if (0 < try vctSolver(vct_time_limit, vct_depth_limit, is_black, brain)) {
        return getOptimal();
    }
    best[0] = search_terminate_value;
    search_depth_limit = search_depth_limit_default;
    search_width_limit = search_width_limit_default;
    while (!isTimeOut() and search_depth_limit <= 100) : (search_depth_limit += 2) {
        optimal[0] = search_terminate_value;
        const score = try alphabeta(0, is_black, -search_win_threshold, search_win_threshold);
        if (score == search_terminate_value) {
            break;
        }
        response(.Message, "depth={}, score={}, optimal=({},{})", .{ search_depth_limit, score, optimal[0], optimal[1] });
        best = optimal;
        if ((is_black and score >= search_win_threshold) or (!is_black and score <= -search_win_threshold)) {
            return best;
        }
        const score_abs = std.math.absInt(score) catch unreachable;
        if (score_abs >= search_win_threshold) {
            search_width_limit += 2;
        }
    }
    return if (best[0] == search_terminate_value) error.TimeOut else best;
}

fn eval(p: [2]usize) i32 {
    const x = p[0];
    const y = p[1];
    const score_black = brain.board.evaluate(x, y, true);
    const score_white = brain.board.evaluate(x, y, false);
    const score = 2 * std.math.max(score_black, score_white) + std.math.max(0, std.math.min(score_black, score_white));
    const w = @bitCast(isize, brain.manager.board.dimension[0] / 2);
    const h = @bitCast(isize, brain.manager.board.dimension[1] / 2);
    const delta_x = std.math.absInt(@bitCast(isize, x) - w) catch unreachable;
    const delta_y = std.math.absInt(@bitCast(isize, y) - h) catch unreachable;
    const position_score = @truncate(i32, w + h - delta_x - delta_y);
    return score + position_score;
}

fn compare(context: void, lhs: [2]usize, rhs: [2]usize) bool {
    _ = context;
    return eval(lhs) > eval(rhs);
}

fn alphabeta(depth: usize, is_black: bool, arg_alpha: i32, arg_beta: i32) error{OutOfMemory}!i32 {
    if (depth >= search_depth_limit) {
        if (0 < try vcfSolver(0, 0, is_black, brain)) {
            return search_win_threshold;
        }
        return evaluateAll(brain);
    }
    if (isTimeOut()) {
        return search_terminate_value;
    }
    const width = brain.manager.board.dimension[0];
    const height = brain.manager.board.dimension[1];
    const allocator = brain.manager.allocator;
    var alpha: i32 = arg_alpha;
    var beta: i32 = arg_beta;
    var candidate = try allocator.alloc([2]usize, width * height);
    defer allocator.free(candidate);
    {
        var index: usize = 0;
        var i: usize = 0;
        while (i < width) : (i += 1) {
            var j: usize = 0;
            while (j < height) : (j += 1) {
                candidate[index][0] = i;
                candidate[index][1] = j;
                index += 1;
            }
        }
    }
    sort([2]usize, candidate, {}, compare);
    var count: usize = 0;
    var best_x: usize = search_terminate_value;
    var best_y: usize = search_terminate_value;
    for (candidate) |position| {
        if (count >= search_width_limit) {
            break;
        }
        const x = position[0];
        const y = position[1];
        if (brain.board.get(position) != .None) {
            continue;
        }
        const value = brain.board.evaluate(x, y, is_black);
        if (value < 0) {
            continue;
        }
        if (best_x == search_terminate_value or best_y == search_terminate_value) {
            best_x = x;
            best_y = y;
        }
        if (value >= 100_000) {
            if (depth == 0) {
                optimal = position;
            }
            if (is_black) {
                return search_win_threshold;
            } else {
                return -search_win_threshold;
            }
        }
        brain.board.update(.{ x, y }, if (is_black) .Black else .White);
        const score: i32 = try alphabeta(depth + 1, !is_black, alpha, beta);
        brain.board.update(.{ x, y }, .None);
        count += 1;
        if (score == search_terminate_value) {
            return search_terminate_value;
        }
        if (is_black) {
            if (score > alpha) {
                best_x = x;
                best_y = y;
                alpha = score;
            }
        } else {
            if (score < beta) {
                best_x = x;
                best_y = y;
                beta = score;
            }
        }
        if (beta <= alpha) {
            if (depth == 0) {
                optimal[0] = best_x;
                optimal[1] = best_y;
            }
            if (is_black) {
                return beta;
            } else {
                return alpha;
            }
        }
    }
    if (depth == 0) {
        optimal[0] = best_x;
        optimal[1] = best_y;
    }
    if (is_black) {
        return alpha;
    } else {
        return beta;
    }
}
