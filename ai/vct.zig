const std = @import("std");
const Timer = std.time.Timer;
const sort = std.sort.sort;
const Brain = @import("ai.zig").Brain;
const response = @import("../protocol.zig").response;

var time_limit: u64 = undefined;
var timer: std.time.Timer = undefined;
var max_depth: usize = undefined;
var brain: *Brain = undefined;
var optimal: [2]usize = undefined;

const search_terminate_value = 123_456_789;

fn isTimeOut() bool {
    return timer.read() >= time_limit;
}

pub fn getOptimal() [2]usize {
    return optimal;
}

pub fn vcfSolver(arg_time_limit: u64, arg_max_depth: usize, is_black: bool, arg_brain: *Brain) error{OutOfMemory}!i8 {
    timer = Timer.start() catch unreachable;
    time_limit = arg_time_limit;
    max_depth = arg_max_depth;
    brain = arg_brain;
    optimal[0] = search_terminate_value;
    const result = try vcf(0, is_black);
    if (arg_max_depth > 0) {
        if (optimal[0] != search_terminate_value) {
            response(.Message, "VCF suggest: {d} {d}", .{ optimal[0], optimal[1] });
        }
        response(.Message, "VCF costs {d} ms", .{timer.read() / std.time.ns_per_ms});
    }
    return result;
}

pub fn vctSolver(arg_time_limit: u64, arg_max_depth: usize, is_black: bool, arg_brain: *Brain) error{OutOfMemory}!i8 {
    timer = Timer.start() catch unreachable;
    time_limit = arg_time_limit;
    max_depth = arg_max_depth;
    brain = arg_brain;
    optimal[0] = search_terminate_value;
    const result = try vct(0, is_black);
    if (arg_max_depth > 0) {
        if (optimal[0] != search_terminate_value) {
            response(.Message, "VCT suggest: {d} {d}", .{ optimal[0], optimal[1] });
        }
        response(.Message, "VCT costs {d} ms", .{timer.read() / std.time.ns_per_ms});
    }
    return result;
}

fn eval(p: [2]usize) i32 {
    const x = p[0];
    const y = p[1];
    const score_black = brain.board.evaluate(x, y, true);
    const score_white = brain.board.evaluate(x, y, false);
    const score = std.math.max(score_black, score_white);
    return score;
}

fn compare(context: void, lhs: [2]usize, rhs: [2]usize) bool {
    _ = context;
    return eval(lhs) > eval(rhs);
}

pub fn vcf(depth: usize, is_black: bool) error{OutOfMemory}!i8 {
    const width = brain.manager.board.dimension[0];
    const height = brain.manager.board.dimension[1];
    const allocator = brain.manager.allocator;
    var candidate = try allocator.alloc([2]usize, width * height);
    defer allocator.free(candidate);
    {
        var index: usize = 0;
        var i: usize = 0;
        while (i < width) : (i += 1) {
            var j: usize = 0;
            while (j < height) : (j += 1) {
                candidate[index] = [2]usize{ i, j };
                index += 1;
            }
        }
    }
    sort([2]usize, candidate, {}, compare);
    for (candidate) |position| { // attack 5
        const x = position[0];
        const y = position[1];
        if (brain.board.get(position) != .None) {
            continue;
        }
        const value = brain.board.evaluate(x, y, is_black);
        if (value >= 100_000) {
            if (depth == 0) {
                optimal = position;
            }
            return 1;
        }
    }
    for (candidate) |position| { // defend 5
        const x = position[0];
        const y = position[1];
        if (brain.board.get(position) != .None) {
            continue;
        }
        const value = brain.board.evaluate(x, y, !is_black);
        if (value >= 100_000) {
            if (brain.board.evaluate(x, y, is_black) < 0) { // TODO: replace with renju.checkLegal
                return -1;
            }
            brain.board.update([2]usize{ x, y }, if (is_black) .Black else .White);
            const ret = -try vcf(depth + 1, !is_black);
            brain.board.update([2]usize{ x, y }, .None);
            if (depth == 0) {
                optimal = position;
            }
            if (ret > 0) {
                return 1;
            }
            if (ret < 0) {
                return -1;
            }
            return 0;
        }
    }
    for (candidate) |position| { // attack 4f
        const x = position[0];
        const y = position[1];
        if (brain.board.get(position) != .None) {
            continue;
        }
        const value = brain.board.evaluate(x, y, is_black);
        if (value >= 45_000) {
            if (depth == 0) {
                optimal = position;
            }
            return 1;
        }
    }
    if (isTimeOut()) {
        return 0;
    }
    for (candidate) |position| { // attack 43
        const x = position[0];
        const y = position[1];
        if (brain.board.get(position) != .None) {
            continue;
        }
        const value = brain.board.evaluate(x, y, is_black);
        if (value >= 20_000 and value < 45000) {
            brain.board.update([2]usize{ x, y }, if (is_black) .Black else .White);
            const ret = -try vcf(depth + 1, !is_black);
            brain.board.update([2]usize{ x, y }, .None);
            if (ret > 0) {
                if (depth == 0) {
                    optimal = position;
                }
                return 1;
            }
        }
    }
    if (depth >= max_depth) {
        return 0;
    }
    for (candidate) |position| { // attack 4s
        const x = position[0];
        const y = position[1];
        if (brain.board.get(position) != .None) {
            continue;
        }
        const value = brain.board.evaluate(x, y, is_black);
        if (value < 0 or value >= 20_000) {
            continue;
        }
        if (brain.board.isFourSleep(x, y, is_black)) {
            brain.board.update([2]usize{ x, y }, if (is_black) .Black else .White);
            const ret = -try vcf(depth + 1, !is_black);
            brain.board.update([2]usize{ x, y }, .None);
            if (ret > 0) {
                if (depth == 0) {
                    optimal = position;
                }
                return 1;
            }
        }
    }
    return 0;
}

pub fn vct(depth: usize, is_black: bool) error{OutOfMemory}!i8 {
    const width = brain.manager.board.dimension[0];
    const height = brain.manager.board.dimension[1];
    const allocator = brain.manager.allocator;
    var candidate = try allocator.alloc([2]usize, width * height);
    defer allocator.free(candidate);
    {
        var index: usize = 0;
        var i: usize = 0;
        while (i < width) : (i += 1) {
            var j: usize = 0;
            while (j < height) : (j += 1) {
                candidate[index] = [2]usize{ i, j };
                index += 1;
            }
        }
    }
    sort([2]usize, candidate, {}, compare);
    for (candidate) |position| { // attack 5
        const x = position[0];
        const y = position[1];
        if (brain.board.get(position) != .None) {
            continue;
        }
        const value = brain.board.evaluate(x, y, is_black);
        if (value >= 100_000) {
            if (depth == 0) {
                optimal = position;
            }
            return 1;
        }
    }
    for (candidate) |position| { // defend 5
        const x = position[0];
        const y = position[1];
        if (brain.board.get(position) != .None) {
            continue;
        }
        const value = brain.board.evaluate(x, y, !is_black);
        if (value >= 100_000) {
            if (brain.board.evaluate(x, y, is_black) < 0) { // TODO: replace with renju.checkLegal
                return -1;
            }
            brain.board.update([2]usize{ x, y }, if (is_black) .Black else .White);
            const ret = -try vct(depth + 1, !is_black);
            brain.board.update([2]usize{ x, y }, .None);
            if (depth == 0) {
                optimal = position;
            }
            if (ret > 0) {
                return 1;
            }
            if (ret < 0) {
                return -1;
            }
            return 0;
        }
    }
    for (candidate) |position| { // attack 4f
        const x = position[0];
        const y = position[1];
        if (brain.board.get(position) != .None) {
            continue;
        }
        const value = brain.board.evaluate(x, y, is_black);
        if (value >= 45_000) {
            if (depth == 0) {
                optimal = position;
            }
            return 1;
        }
    }
    if (isTimeOut()) {
        return 0;
    }
    if (depth >= max_depth) {
        return 0;
    }
    var defense: ?bool = null;
    var defense_postion: [2]usize = undefined;
    for (candidate) |position| { // defend 4f
        const x = position[0];
        const y = position[1];
        if (brain.board.get(position) != .None) {
            continue;
        }
        const value = brain.board.evaluate(x, y, !is_black);
        if (value >= 45_000) {
            if (defense == null) {
                defense = false;
            }
            brain.board.update([2]usize{ x, y }, if (is_black) .Black else .White);
            const ret = -try vct(depth + 1, !is_black);
            brain.board.update([2]usize{ x, y }, .None);
            if (ret > 0) {
                if (depth == 0) {
                    optimal = position;
                }
                return 1;
            }
            if (ret == 0) {
                defense = true;
                defense_postion = position;
            }
        }
    }
    if (defense) |ok| {
        if (ok) {
            if (depth == 0) {
                optimal = defense_postion;
            }
            return 0;
        }
        return -1;
    }
    for (candidate) |position| { // attack 43
        const x = position[0];
        const y = position[1];
        if (brain.board.get(position) != .None) {
            continue;
        }
        const value = brain.board.evaluate(x, y, is_black);
        if (value >= 20_000 and value < 45_000) {
            brain.board.update([2]usize{ x, y }, if (is_black) .Black else .White);
            const ret = -try vct(depth + 1, !is_black);
            brain.board.update([2]usize{ x, y }, .None);
            if (ret > 0) {
                if (depth == 0) {
                    optimal = position;
                }
                return 1;
            }
        }
    }
    for (candidate) |position| { // attack 4s
        const x = position[0];
        const y = position[1];
        if (brain.board.get(position) != .None) {
            continue;
        }
        const value = brain.board.evaluate(x, y, is_black);
        if (value < 0 or value >= 20_000) {
            continue;
        }
        if (brain.board.isFourSleep(x, y, is_black)) {
            brain.board.update([2]usize{ x, y }, if (is_black) .Black else .White);
            const ret = -try vct(depth + 1, !is_black);
            brain.board.update([2]usize{ x, y }, .None);
            if (ret > 0) {
                if (depth == 0) {
                    optimal = position;
                }
                return 1;
            }
        }
    }
    for (candidate) |position| { // attack 33
        const x = position[0];
        const y = position[1];
        if (brain.board.get(position) != .None) {
            continue;
        }
        const value = brain.board.evaluate(x, y, is_black);
        if (value >= 10_000 and value < 20_000) {
            brain.board.update([2]usize{ x, y }, if (is_black) .Black else .White);
            const ret = -try vct(depth + 1, !is_black);
            brain.board.update([2]usize{ x, y }, .None);
            if (ret > 0) {
                if (depth == 0) {
                    optimal = position;
                }
                return 1;
            }
        }
    }
    for (candidate) |position| { // attack 3f
        const x = position[0];
        const y = position[1];
        if (brain.board.get(position) != .None) {
            continue;
        }
        const value = brain.board.evaluate(x, y, is_black);
        if (value < 0 or value >= 10_000) {
            continue;
        }
        if (brain.board.isThree(x, y, is_black)) {
            brain.board.update([2]usize{ x, y }, if (is_black) .Black else .White);
            const ret = -try vct(depth + 1, !is_black);
            brain.board.update([2]usize{ x, y }, .None);
            if (ret > 0) {
                if (depth == 0) {
                    optimal = position;
                }
                return 1;
            }
        }
    }
    return 0;
}
