const std = @import("std");
const BoundedArray = std.BoundedArray;
const Board = @import("board.zig").Board;

const DataType = i32;
const DataVecN = 256 / @bitSizeOf(DataType);
const DataVec = @Vector(DataVecN, DataType);

const weight_min = -126;
const weight_max = 126;
const grad_min = -1000;
const grad_max = 1000;

fn clamp(val: anytype, min: @TypeOf(val), max: @TypeOf(val)) @TypeOf(val) {
    return if (val >= max) max else if (val <= min) min else val;
}

fn __quantmoid(x: DataVec) DataVec {
    const v0 = @splat(DataVecN, @as(DataType, 0));
    const v64 = @splat(DataVecN, @as(DataType, 64));
    const v127 = @splat(DataVecN, @as(DataType, 127));
    const x_sgn = x < v0;
    const x_abs = @select(DataType, x_sgn, -x, x);
    const xx = @select(DataType, x_abs < v127, x_abs - v127, v0);
    const yy = (xx * xx) >> @splat(DataVecN, @as(u4, 8));
    return @select(DataType, x_sgn, v64 - yy, yy);
}

fn quantmoid(comptime size: comptime_int, input: [size]DataType, output: *[size]DataType) void {
    if (comptime size % DataVecN != 0) {
        @compileError("");
    }
    var index: usize = 0;
    while (index < size) : (index += DataVecN) {
        output[index..][0..DataVecN].* = __quantmoid(input[index..][0..DataVecN].*);
    }
}

fn quantmoid_backward(comptime size: comptime_int, input: [size]DataType, input_grad: *[size]f32, output_grad: [size]f32) void {
    var i: usize = 0;
    while (i < size) : (i += 1) {
        if (input[i] >= 127) {
            input_grad[i] = 1.0 / 128.0;
        } else if (input[i] <= 127) {
            input_grad[i] = -1.0 / 128.0;
        } else if (input[i] >= 0) {
            input_grad[i] = @intToFloat(f32, input[i] - 127) / 128;
        } else {
            input_grad[i] = @intToFloat(f32, -(-input[i] - 127)) / 128;
        }
        input_grad[i] *= output_grad[i];
        input_grad[i] = clamp(input_grad[i], grad_min, grad_max);
    }
}

fn linear(comptime input_size: comptime_int, comptime output_size: comptime_int, input: [input_size]DataType, output: *[output_size]DataType, weight: [input_size][output_size]DataType) void {
    if (comptime output_size % DataVecN != 0) {
        @compileError("");
    }
    var regs: [output_size / DataVecN]DataVec = [_]DataVec{@splat(DataVecN, @as(DataType, 0))} ** (output_size / DataVecN); // no bias
    var k: usize = 0;
    var index: usize = 0;
    var val: DataVec = undefined;
    for (input) |value, i| {
        val = @splat(DataVecN, value);
        k = 0;
        index = 0;
        while (index < output_size) : (index += DataVecN) {
            const w: DataVec = weight[i][index..][0..DataVecN].*;
            regs[k] = regs[k] + val * w;
            k += 1;
        }
    }
    while (index < output_size) : (index += DataVecN) {
        output[index..][0..DataVecN].* = regs[k];
        k += 1;
    }
}

fn linear_backward(comptime input_size: comptime_int, comptime output_size: comptime_int, input: [input_size]DataType, weight: [input_size][output_size]DataType, input_grad: *[input_size]f32, output_grad: [output_size]f32, weight_grad: *[input_size][output_size]f32) void {
    var i: usize = 0;
    while (i < input_size) : (i += 1) {
        var j: usize = 0;
        while (j < output_size) : (j += 1) {
            weight_grad[i][j] = output_grad[j] * @intToFloat(f32, input[i]);
            weight_grad[i][j] = clamp(weight_grad[i][j], grad_min, grad_max);
        }
    }
    i = 0;
    while (i < input_size) : (i += 1) {
        var j: usize = 0;
        input_grad[i] = 0;
        while (j < output_size) : (j += 1) {
            input_grad[i] += output_grad[j] * @intToFloat(f32, weight[i][j]);
        }
        input_grad[i] = clamp(input_grad[i], grad_min, grad_max);
    }
}

fn accumulate(comptime input_size: comptime_int, comptime output_size: comptime_int, activate: []const usize, deactivate: []const usize, output: *[output_size]DataType, weight: [input_size][output_size]DataType) void {
    if (comptime output_size % DataVecN != 0) {
        @compileError("");
    }
    var regs: [output_size / DataVecN]DataVec = undefined;
    var k: usize = 0;
    var index: usize = 0;
    while (index < output_size) : (index += DataVecN) {
        regs[k] = output[index..][0..DataVecN].*;
        k += 1;
    }
    for (activate) |i| {
        k = 0;
        index = 0;
        while (index < output_size) : (index += DataVecN) {
            const w: DataVec = weight[i][index..][0..DataVecN].*;
            regs[k] = regs[k] + w;
            k += 1;
        }
    }
    for (deactivate) |i| {
        k = 0;
        index = 0;
        while (index < output_size) : (index += DataVecN) {
            const w: DataVec = weight[i][index..][0..DataVecN].*;
            regs[k] = regs[k] - w;
            k += 1;
        }
    }
    k = 0;
    index = 0;
    while (index < output_size) : (index += DataVecN) {
        output[index..][0..DataVecN].* = regs[k];
        k += 1;
    }
}

const LAYER0_INPUT_SIZE = 512;
const LAYER0_OUTPUT_SIZE = 32;
const LAYER1_INPUT_SIZE = LAYER0_OUTPUT_SIZE;
const LAYER1_OUTPUT_SIZE = 32;
const LAYER2_INPUT_SIZE = LAYER1_OUTPUT_SIZE;
const LAYER2_OUTPUT_SIZE = 8;
const LAYER3_INPUT_SIZE = LAYER2_OUTPUT_SIZE;
const LAYER3_OUTPUT_SIZE = 1;

const Weights = struct {
    layer0_weight: [LAYER0_INPUT_SIZE][LAYER0_OUTPUT_SIZE]DataType,
    layer1_weight: [LAYER1_INPUT_SIZE][LAYER1_OUTPUT_SIZE]DataType,
    layer2_weight: [LAYER2_INPUT_SIZE][LAYER2_OUTPUT_SIZE]DataType,
    layer3_weight: [LAYER3_INPUT_SIZE][LAYER3_OUTPUT_SIZE]DataType,

    const Self = @This();

    pub fn load(reader: anytype) !Self {
        var layer0_weight: [LAYER0_INPUT_SIZE][LAYER0_OUTPUT_SIZE]DataType = undefined;
        var layer1_weight: [LAYER1_INPUT_SIZE][LAYER1_OUTPUT_SIZE]DataType = undefined;
        var layer2_weight: [LAYER2_INPUT_SIZE][LAYER2_OUTPUT_SIZE]DataType = undefined;
        var layer3_weight: [LAYER3_INPUT_SIZE][LAYER3_OUTPUT_SIZE]DataType = undefined;
        var i: usize = 0;
        while (i < LAYER0_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER0_OUTPUT_SIZE) : (j += 1) {
                layer0_weight[i][j] = try reader.readIntLittle(DataType);
            }
        }
        i = 0;
        while (i < LAYER1_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER1_OUTPUT_SIZE) : (j += 1) {
                layer1_weight[i][j] = try reader.readIntLittle(DataType);
            }
        }
        i = 0;
        while (i < LAYER2_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER2_OUTPUT_SIZE) : (j += 1) {
                layer2_weight[i][j] = try reader.readIntLittle(DataType);
            }
        }
        i = 0;
        while (i < LAYER3_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER3_OUTPUT_SIZE) : (j += 1) {
                layer3_weight[i][j] = try reader.readIntLittle(DataType);
            }
        }
        return Self{ .layer0_weight = layer0_weight, .layer1_weight = layer1_weight, .layer2_weight = layer2_weight, .layer3_weight = layer3_weight };
    }

    pub fn store(self: *const Self, writer: anytype) !void {
        var i: usize = 0;
        while (i < LAYER0_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER0_OUTPUT_SIZE) : (j += 1) {
                try writer.writeIntLittle(DataType, self.layer0_weight[i][j]);
            }
        }
        i = 0;
        while (i < LAYER1_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER1_OUTPUT_SIZE) : (j += 1) {
                try writer.writeIntLittle(DataType, self.layer1_weight[i][j]);
            }
        }
        i = 0;
        while (i < LAYER2_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER2_OUTPUT_SIZE) : (j += 1) {
                try writer.writeIntLittle(DataType, self.layer2_weight[i][j]);
            }
        }
        i = 0;
        while (i < LAYER3_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER3_OUTPUT_SIZE) : (j += 1) {
                try writer.writeIntLittle(DataType, self.layer3_weight[i][j]);
            }
        }
    }
};

pub const Nnue = struct {
    net: Weights,
    layer0: [LAYER0_INPUT_SIZE]DataType = [_]DataType{0} ** LAYER0_INPUT_SIZE,
    hidden0: [LAYER0_OUTPUT_SIZE]DataType = [_]DataType{0} ** LAYER0_OUTPUT_SIZE,
    layer1: [LAYER1_INPUT_SIZE]DataType = undefined,
    hidden1: [LAYER0_OUTPUT_SIZE]DataType = undefined,
    layer2: [LAYER2_INPUT_SIZE]DataType = undefined,
    hidden2: [LAYER2_OUTPUT_SIZE]DataType = undefined,
    layer3: [LAYER3_INPUT_SIZE]DataType = undefined,
    result: i32 = undefined,

    const Self = @This();

    pub fn init(reader: anytype) !Self {
        var net = try Weights.load(reader);
        return Self{ .net = net };
    }

    // Lazy update for layer 0
    fn update(self: *Self, board: *const Board) void {
        const width = 15;
        const height = 15;
        var i: usize = 0;
        var activate = BoundedArray(usize, width * height).init(0) catch unreachable;
        var deactivate = BoundedArray(usize, width * height).init(0) catch unreachable;
        while (i < width) : (i += 1) {
            var j: usize = 0;
            while (j < height) : (j += 1) {
                const color = board.get(.{ i, j });
                const index = i * height + width;
                switch (color) {
                    .None => {
                        if (self.layer0[index] != 0) {
                            self.layer0[index] = 0;
                            deactivate.append(index) catch unreachable;
                        }
                        if (self.layer0[index + LAYER0_INPUT_SIZE / 2] != 0) {
                            self.layer0[index + LAYER0_INPUT_SIZE / 2] = 0;
                            deactivate.append(index + LAYER0_INPUT_SIZE / 2) catch unreachable;
                        }
                    },
                    .Black => {
                        if (self.layer0[index] == 0) {
                            self.layer0[index] = 1;
                            activate.append(index) catch unreachable;
                        }
                        if (self.layer0[index + LAYER0_INPUT_SIZE / 2] != 0) {
                            self.layer0[index + LAYER0_INPUT_SIZE / 2] = 0;
                            deactivate.append(index + LAYER0_INPUT_SIZE / 2) catch unreachable;
                        }
                    },
                    .White => {
                        if (self.layer0[index] != 0) {
                            self.layer0[index] = 0;
                            deactivate.append(index) catch unreachable;
                        }
                        if (self.layer0[index + LAYER0_INPUT_SIZE / 2] == 0) {
                            self.layer0[index + LAYER0_INPUT_SIZE / 2] = 1;
                            activate.append(index + LAYER0_INPUT_SIZE / 2) catch unreachable;
                        }
                    },
                    else => unreachable,
                }
            }
        }
        accumulate(LAYER0_INPUT_SIZE, LAYER0_OUTPUT_SIZE, activate.slice(), deactivate.slice(), &self.hidden0, self.net.layer0_weight);
    }

    pub fn evaluate(self: *Self, board: *const Board) i32 {
        self.update(board);
        quantmoid(LAYER0_OUTPUT_SIZE, self.hidden0, &self.layer1);
        linear(LAYER1_INPUT_SIZE, LAYER1_OUTPUT_SIZE, self.layer1, &self.hidden1, self.net.layer1_weight);
        quantmoid(LAYER1_OUTPUT_SIZE, self.hidden1, &self.layer2);
        linear(LAYER2_INPUT_SIZE, LAYER2_OUTPUT_SIZE, self.layer2, &self.hidden2, self.net.layer2_weight);
        quantmoid(LAYER2_OUTPUT_SIZE, self.hidden2, &self.layer3);

        // Layer 3
        var i: usize = 0;
        self.result = 0;
        while (i < LAYER3_INPUT_SIZE) : (i += 1) {
            self.result = self.result + self.layer3[i] * self.net.layer3_weight[i][0];
        }

        return self.result;
    }

    pub fn backwardPropagation(self: *Self, expect: DataType, rate: f32) void {
        const k = 2 * @intToFloat(f32, self.result - expect); // square loss function
        var layer3_grad: [LAYER3_INPUT_SIZE][LAYER3_OUTPUT_SIZE]f32 = [_][LAYER3_OUTPUT_SIZE]f32{[_]f32{0} ** LAYER3_OUTPUT_SIZE} ** LAYER3_INPUT_SIZE;
        var layer3_k: [LAYER3_INPUT_SIZE]f32 = [_]f32{0} ** LAYER3_INPUT_SIZE;
        var hidden2_k: [LAYER2_OUTPUT_SIZE]f32 = [_]f32{0} ** LAYER2_OUTPUT_SIZE;
        var layer2_grad: [LAYER2_INPUT_SIZE][LAYER2_OUTPUT_SIZE]f32 = [_][LAYER2_OUTPUT_SIZE]f32{[_]f32{0} ** LAYER2_OUTPUT_SIZE} ** LAYER2_INPUT_SIZE;
        var layer2_k: [LAYER2_INPUT_SIZE]f32 = [_]f32{0} ** LAYER2_INPUT_SIZE;
        var hidden1_k: [LAYER1_OUTPUT_SIZE]f32 = [_]f32{0} ** LAYER1_OUTPUT_SIZE;
        var layer1_grad: [LAYER1_INPUT_SIZE][LAYER1_OUTPUT_SIZE]f32 = [_][LAYER1_OUTPUT_SIZE]f32{[_]f32{0} ** LAYER1_OUTPUT_SIZE} ** LAYER1_INPUT_SIZE;
        var layer1_k: [LAYER1_INPUT_SIZE]f32 = [_]f32{0} ** LAYER1_INPUT_SIZE;
        var hidden0_k: [LAYER0_OUTPUT_SIZE]f32 = [_]f32{0} ** LAYER0_OUTPUT_SIZE;
        var layer0_grad: [LAYER0_INPUT_SIZE][LAYER0_OUTPUT_SIZE]f32 = [_][LAYER0_OUTPUT_SIZE]f32{[_]f32{0} ** LAYER0_OUTPUT_SIZE} ** LAYER0_INPUT_SIZE;
        var layer0_k: [LAYER0_INPUT_SIZE]f32 = [_]f32{0} ** LAYER0_INPUT_SIZE;
        linear_backward(LAYER3_INPUT_SIZE, LAYER3_OUTPUT_SIZE, self.layer3, self.net.layer3_weight, &layer3_k, .{k}, &layer3_grad);
        quantmoid_backward(LAYER2_OUTPUT_SIZE, self.hidden2, &hidden2_k, layer3_k);
        linear_backward(LAYER2_INPUT_SIZE, LAYER2_OUTPUT_SIZE, self.layer2, self.net.layer2_weight, &layer2_k, hidden2_k, &layer2_grad);
        quantmoid_backward(LAYER1_OUTPUT_SIZE, self.hidden1, &hidden1_k, layer2_k);
        linear_backward(LAYER1_INPUT_SIZE, LAYER1_OUTPUT_SIZE, self.layer1, self.net.layer1_weight, &layer1_k, hidden1_k, &layer1_grad);
        quantmoid_backward(LAYER0_OUTPUT_SIZE, self.hidden0, &hidden0_k, layer1_k);
        linear_backward(LAYER0_INPUT_SIZE, LAYER0_OUTPUT_SIZE, self.layer0, self.net.layer0_weight, &layer0_k, hidden0_k, &layer0_grad);

        var i: usize = 0;
        while (i < LAYER0_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER0_OUTPUT_SIZE) : (j += 1) {
                const old_sign: DataType = if (self.net.layer0_weight[i][j] >= 0) 1 else -1;
                self.net.layer0_weight[i][j] = @floatToInt(DataType, clamp(@intToFloat(f32, self.net.layer0_weight[i][j]) - layer0_grad[i][j] * rate, weight_min, weight_max));
                if (self.net.layer0_weight[i][j] == 0) {
                    self.net.layer0_weight[i][j] = -old_sign;
                }
            }
        }
        i = 0;
        while (i < LAYER1_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER1_OUTPUT_SIZE) : (j += 1) {
                std.log.warn("layer1 grad {} {}: {}", .{ i, j, layer1_grad[i][j] });
                const old_sign: DataType = if (self.net.layer1_weight[i][j] >= 0) 1 else -1;
                self.net.layer1_weight[i][j] = @floatToInt(DataType, clamp(@intToFloat(f32, self.net.layer1_weight[i][j]) - layer1_grad[i][j] * rate, weight_min, weight_max));
                if (self.net.layer1_weight[i][j] == 0) {
                    self.net.layer1_weight[i][j] = -old_sign;
                }
            }
        }
        i = 0;
        while (i < LAYER2_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER2_OUTPUT_SIZE) : (j += 1) {
                const old_sign: DataType = if (self.net.layer2_weight[i][j] >= 0) 1 else -1;
                self.net.layer2_weight[i][j] = @floatToInt(DataType, clamp(@intToFloat(f32, self.net.layer2_weight[i][j]) - layer2_grad[i][j] * rate, weight_min, weight_max));
                if (self.net.layer2_weight[i][j] == 0) {
                    self.net.layer2_weight[i][j] = -old_sign;
                }
            }
        }
        i = 0;
        while (i < LAYER3_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            std.log.warn("layer3 particial {}: {}", .{ i, layer3_k[i] });
            while (j < LAYER3_OUTPUT_SIZE) : (j += 1) {
                std.log.warn("layer3 grad {} {}: {}", .{ i, j, layer3_grad[i][j] });
                const old_sign: DataType = if (self.net.layer3_weight[i][j] >= 0) 1 else -1;
                self.net.layer3_weight[i][j] = @floatToInt(DataType, clamp(@intToFloat(f32, self.net.layer3_weight[i][j]) - layer3_grad[i][j] * rate, weight_min, weight_max));
                if (self.net.layer3_weight[i][j] == 0) {
                    self.net.layer3_weight[i][j] = -old_sign;
                }
            }
        }
    }
};
