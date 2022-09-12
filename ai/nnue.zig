const std = @import("std");
const BoundedArray = std.BoundedArray;
const Board = @import("board.zig").Board;

const DataType = f32;
const DataVecN = 256 / @bitSizeOf(DataType);
const DataVec = @Vector(DataVecN, DataType);

pub fn clamp(value: DataType, min_val: DataType, max_val: DataType) DataType {
    const val_c = if (value < min_val) min_val else value;
    return if (val_c > max_val) max_val else val_c;
}

fn leakyReluUnoptimized(comptime size: comptime_int, comptime alpha: comptime_float, input: [size]DataType, output: *[size]DataType) void {
    var index: usize = 0;
    while (index < size) : (index += 1) {
        const k: DataType = if (input[index] < 0) alpha else 1;
        output[index] = k * input[index];
    }
}

fn leakyReluOptimized(comptime size: comptime_int, comptime alpha: comptime_float, input: [size]DataType, output: *[size]DataType) void {
    if (comptime size % DataVecN != 0) {
        @compileError("");
    }
    var index: usize = 0;
    while (index < size) : (index += DataVecN) {
        const in: DataVec = input[index..][0..DataVecN].*;
        const out = @select(DataType, in < @splat(DataVecN, @as(DataType, 0)), @splat(DataVecN, @as(DataType, alpha)), @splat(DataVecN, @as(DataType, 1))) * in;
        output[index..][0..DataVecN].* = out;
    }
}

pub fn leakyRelu(comptime size: comptime_int, comptime alpha: comptime_float, input: [size]DataType, output: *[size]DataType) void {
    if (comptime size >= DataVecN) {
        leakyReluOptimized(size, alpha, input, output);
    } else {
        leakyReluUnoptimized(size, alpha, input, output);
    }
}

fn leakyReluBackwardUnoptimized(comptime size: comptime_int, comptime alpha: comptime_float, input: [size]DataType, input_grad: *[size]DataType, output_grad: [size]DataType) void {
    var index: usize = 0;
    while (index < size) : (index += 1) {
        const k: DataType = if (input[index] < 0) alpha else 1;
        input_grad[index] = k * output_grad[index];
    }
}

fn leakyReluBackwardOptimized(comptime size: comptime_int, comptime alpha: comptime_float, input: [size]DataType, input_grad: *[size]DataType, output_grad: [size]DataType) void {
    if (comptime size % DataVecN != 0) {
        @compileError("");
    }
    var index: usize = 0;
    while (index < size) : (index += DataVecN) {
        const in: DataVec = input[index..][0..DataVecN].*;
        const out_grad: DataVec = output_grad[index..][0..DataVecN].*;
        const in_grad = @select(DataType, in < @splat(DataVecN, @as(DataType, 0)), @splat(DataVecN, @as(DataType, alpha)), @splat(DataVecN, @as(DataType, 1))) * out_grad;
        input_grad[index..][0..DataVecN].* = in_grad;
    }
}

pub fn leakyReluBackward(comptime size: comptime_int, comptime alpha: comptime_float, input: [size]DataType, input_grad: *[size]DataType, output_grad: [size]DataType) void {
    if (comptime size >= DataVecN) {
        leakyReluBackwardOptimized(size, alpha, input, input_grad, output_grad);
    } else {
        leakyReluBackwardUnoptimized(size, alpha, input, input_grad, output_grad);
    }
}

fn linearUnoptimized(comptime input_size: comptime_int, comptime output_size: comptime_int, input: [input_size]DataType, weight: [input_size][output_size]DataType, output: *[output_size]DataType) void {
    var i: usize = 0;
    while (i < output_size) : (i += 1) {
        var j: usize = 0;
        output[i] = 0;
        while (j < input_size) : (j += 1) {
            output[i] += input[j] * weight[j][i];
        }
    }
}

fn linearOptimized(comptime input_size: comptime_int, comptime output_size: comptime_int, input: [input_size]DataType, weight: [input_size][output_size]DataType, output: *[output_size]DataType) void {
    if (comptime output_size % DataVecN != 0) {
        @compileError("");
    }
    var regs: [output_size / DataVecN]DataVec = [_]DataVec{@splat(DataVecN, @as(DataType, 0))} ** (output_size / DataVecN);
    for (input) |value, j| {
        var k: usize = 0;
        var i: usize = 0;
        while (i < output_size) : (i += DataVecN) {
            const w: DataVec = weight[j][i..][0..DataVecN].*;
            regs[k] = regs[k] + @splat(DataVecN, value) * w;
            k += 1;
        }
    }
    var k: usize = 0;
    var index: usize = 0;
    while (index < output_size) : (index += DataVecN) {
        output[index..][0..DataVecN].* = regs[k];
        k += 1;
    }
}

pub fn linear(comptime input_size: comptime_int, comptime output_size: comptime_int, input: [input_size]DataType, weight: [input_size][output_size]DataType, output: *[output_size]DataType) void {
    if (comptime output_size >= DataVecN) {
        linearOptimized(input_size, output_size, input, weight, output);
    } else {
        linearUnoptimized(input_size, output_size, input, weight, output);
    }
}

fn linearBackwardUnoptimized(comptime input_size: comptime_int, comptime output_size: comptime_int, input: [input_size]DataType, weight: [input_size][output_size]DataType, input_grad: *[input_size]DataType, weight_grad: *[input_size][output_size]DataType, output_grad: [output_size]DataType) void {
    var i: usize = 0;
    while (i < input_size) : (i += 1) {
        var j: usize = 0;
        while (j < output_size) : (j += 1) {
            weight_grad[i][j] = output_grad[j] * input[i];
        }
    }
    i = 0;
    while (i < input_size) : (i += 1) {
        var j: usize = 0;
        input_grad[i] = 0;
        while (j < output_size) : (j += 1) {
            input_grad[i] += output_grad[j] * weight[i][j];
        }
    }
}

fn linearBackwardOptimized(comptime input_size: comptime_int, comptime output_size: comptime_int, input: [input_size]DataType, weight: [input_size][output_size]DataType, input_grad: *[input_size]DataType, weight_grad: *[input_size][output_size]DataType, output_grad: [output_size]DataType) void {
    if (comptime output_size % DataVecN != 0) {
        @compileError("");
    }
    for (input) |value, i| {
        var j: usize = 0;
        while (j < output_size) : (j += DataVecN) {
            const out_grad: DataVec = output_grad[j..][0..DataVecN].*;
            const w_grad = out_grad * @splat(DataVecN, value);
            weight_grad[i][j..][0..DataVecN].* = w_grad;
        }
    }
    var i: usize = 0;
    while (i < input_size) : (i += 1) {
        var reg: DataVec = @splat(DataVecN, @as(DataType, 0));
        var j: usize = 0;
        while (j < output_size) : (j += DataVecN) {
            const out_grad: DataVec = output_grad[j..][0..DataVecN].*;
            const w: DataVec = weight[i][j..][0..DataVecN].*;
            reg = reg + out_grad * w;
        }
        input_grad[i] = @reduce(.Add, reg);
    }
}

pub fn linearBackward(comptime input_size: comptime_int, comptime output_size: comptime_int, input: [input_size]DataType, weight: [input_size][output_size]DataType, input_grad: *[input_size]DataType, weight_grad: *[input_size][output_size]DataType, output_grad: [output_size]DataType) void {
    if (comptime output_size >= DataVecN) {
        linearBackwardOptimized(input_size, output_size, input, weight, input_grad, weight_grad, output_grad);
    } else {
        linearBackwardUnoptimized(input_size, output_size, input, weight, input_grad, weight_grad, output_grad);
    }
}

pub fn accumulate(comptime input_size: comptime_int, comptime output_size: comptime_int, activate: []const usize, deactivate: []const usize, weight: [input_size][output_size]DataType, output: *[output_size]DataType) void {
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

// Read raw bytes from .bin file
fn read(reader: anytype, comptime T: type) !T {
    const bytes = try reader.readBytesNoEof(@sizeOf(T));
    return @ptrCast(*align(1) const T, &bytes).*;
}

// Write raw bytes into .bin file
fn write(writer: anytype, comptime T: type, value: T) !void {
    var bytes: [@sizeOf(T)]u8 = undefined;
    @ptrCast(*align(1) T, &bytes).* = value;
    try writer.writeAll(bytes[0..]);
}

const LAYER0_INPUT_SIZE = 512;
const LAYER0_OUTPUT_SIZE = 32;
const LAYER1_INPUT_SIZE = LAYER0_OUTPUT_SIZE;
const LAYER1_OUTPUT_SIZE = 8;
const LAYER2_INPUT_SIZE = LAYER1_OUTPUT_SIZE;
const LAYER2_OUTPUT_SIZE = 1;

const Weights = struct {
    layer0_weight: [LAYER0_INPUT_SIZE][LAYER0_OUTPUT_SIZE]DataType,
    layer1_weight: [LAYER1_INPUT_SIZE][LAYER1_OUTPUT_SIZE]DataType,
    layer2_weight: [LAYER2_INPUT_SIZE][LAYER2_OUTPUT_SIZE]DataType,

    const Self = @This();

    pub fn load(reader: anytype) !Self {
        var layer0_weight: [LAYER0_INPUT_SIZE][LAYER0_OUTPUT_SIZE]DataType = undefined;
        var layer1_weight: [LAYER1_INPUT_SIZE][LAYER1_OUTPUT_SIZE]DataType = undefined;
        var layer2_weight: [LAYER2_INPUT_SIZE][LAYER2_OUTPUT_SIZE]DataType = undefined;
        var i: usize = 0;
        while (i < LAYER0_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER0_OUTPUT_SIZE) : (j += 1) {
                layer0_weight[i][j] = try read(reader, DataType);
            }
        }
        i = 0;
        while (i < LAYER1_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER1_OUTPUT_SIZE) : (j += 1) {
                layer1_weight[i][j] = try read(reader, DataType);
            }
        }
        i = 0;
        while (i < LAYER2_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER2_OUTPUT_SIZE) : (j += 1) {
                layer2_weight[i][j] = try read(reader, DataType);
            }
        }
        return Self{ .layer0_weight = layer0_weight, .layer1_weight = layer1_weight, .layer2_weight = layer2_weight };
    }

    pub fn store(self: *const Self, writer: anytype) !void {
        var i: usize = 0;
        while (i < LAYER0_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER0_OUTPUT_SIZE) : (j += 1) {
                try write(writer, DataType, self.layer0_weight[i][j]);
            }
        }
        i = 0;
        while (i < LAYER1_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER1_OUTPUT_SIZE) : (j += 1) {
                try write(writer, DataType, self.layer1_weight[i][j]);
            }
        }
        i = 0;
        while (i < LAYER2_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER2_OUTPUT_SIZE) : (j += 1) {
                try write(writer, DataType, self.layer2_weight[i][j]);
            }
        }
    }
};

pub const Nnue = struct {
    net: Weights,
    layer0: [LAYER0_INPUT_SIZE]DataType = [_]DataType{0} ** LAYER0_INPUT_SIZE,
    hidden0: [LAYER0_OUTPUT_SIZE]DataType = [_]DataType{0} ** LAYER0_OUTPUT_SIZE,
    layer1: [LAYER1_INPUT_SIZE]DataType = undefined,
    hidden1: [LAYER1_OUTPUT_SIZE]DataType = undefined,
    layer2: [LAYER2_INPUT_SIZE]DataType = undefined,
    hidden2: [LAYER2_OUTPUT_SIZE]DataType = undefined,
    layer3: [LAYER2_OUTPUT_SIZE]DataType = undefined,

    const Self = @This();

    pub fn init(reader: anytype) !Self {
        var net = try Weights.load(reader);
        return Self{ .net = net };
    }

    // Lazy update for layer 0
    fn update(self: *Self, board: *const Board) void {
        const width = 15;
        const height = 15;
        var activate = BoundedArray(usize, width * height).init(0) catch unreachable;
        var deactivate = BoundedArray(usize, width * height).init(0) catch unreachable;
        var i: usize = 0;
        while (i < width) : (i += 1) {
            var j: usize = 0;
            while (j < height) : (j += 1) {
                const color = board.get(.{ i, j });
                const index = i * height + j;
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
        accumulate(LAYER0_INPUT_SIZE, LAYER0_OUTPUT_SIZE, activate.slice(), deactivate.slice(), self.net.layer0_weight, &self.hidden0);
    }

    pub fn evaluate(self: *Self, board: *const Board) i32 {
        self.update(board);
        leakyRelu(LAYER0_OUTPUT_SIZE, 0.1, self.hidden0, &self.layer1);
        linear(LAYER1_INPUT_SIZE, LAYER1_OUTPUT_SIZE, self.layer1, self.net.layer1_weight, &self.hidden1);
        leakyRelu(LAYER1_OUTPUT_SIZE, 0.1, self.hidden1, &self.layer2);
        linear(LAYER2_INPUT_SIZE, LAYER2_OUTPUT_SIZE, self.layer2, self.net.layer2_weight, &self.hidden2);
        leakyRelu(LAYER2_OUTPUT_SIZE, 0.1, self.hidden2, &self.layer3);
        return @floatToInt(i32, clamp(self.layer3[0], -10_000, 10_000));
    }

    pub fn backwardPropagation(self: *Self, expect: i32, rate: DataType) void {
        const layer3_k: [LAYER2_OUTPUT_SIZE]DataType = .{self.layer3[0] - @intToFloat(DataType, expect)};
        var hidden2_k: [LAYER2_OUTPUT_SIZE]DataType = undefined;
        var layer2_grad: [LAYER2_INPUT_SIZE][LAYER2_OUTPUT_SIZE]DataType = undefined;
        var layer2_k: [LAYER2_INPUT_SIZE]DataType = undefined;
        var hidden1_k: [LAYER1_OUTPUT_SIZE]DataType = undefined;
        var layer1_grad: [LAYER1_INPUT_SIZE][LAYER1_OUTPUT_SIZE]DataType = undefined;
        var layer1_k: [LAYER1_INPUT_SIZE]DataType = undefined;
        var hidden0_k: [LAYER0_OUTPUT_SIZE]DataType = undefined;
        var layer0_grad: [LAYER0_INPUT_SIZE][LAYER0_OUTPUT_SIZE]DataType = undefined;
        var layer0_k: [LAYER0_INPUT_SIZE]DataType = undefined;
        leakyReluBackward(LAYER2_OUTPUT_SIZE, 0.1, self.hidden2, &hidden2_k, layer3_k);
        linearBackward(LAYER2_INPUT_SIZE, LAYER2_OUTPUT_SIZE, self.layer2, self.net.layer2_weight, &layer2_k, &layer2_grad, hidden2_k);
        leakyReluBackward(LAYER1_OUTPUT_SIZE, 0.1, self.hidden1, &hidden1_k, layer2_k);
        linearBackward(LAYER1_INPUT_SIZE, LAYER1_OUTPUT_SIZE, self.layer1, self.net.layer1_weight, &layer1_k, &layer1_grad, hidden1_k);
        leakyReluBackward(LAYER0_OUTPUT_SIZE, 0.1, self.hidden0, &hidden0_k, layer1_k);
        linearBackward(LAYER0_INPUT_SIZE, LAYER0_OUTPUT_SIZE, self.layer0, self.net.layer0_weight, &layer0_k, &layer0_grad, hidden0_k);

        const lambda = 0.05;
        var i: usize = 0;
        while (i < LAYER0_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER0_OUTPUT_SIZE) : (j += 1) {
                self.net.layer0_weight[i][j] -= rate * (layer0_grad[i][j] + lambda * self.net.layer0_weight[i][j]);
            }
        }
        i = 0;
        while (i < LAYER1_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER1_OUTPUT_SIZE) : (j += 1) {
                self.net.layer1_weight[i][j] -= rate * (layer1_grad[i][j] + lambda * self.net.layer1_weight[i][j]);
            }
        }
        i = 0;
        while (i < LAYER2_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER2_OUTPUT_SIZE) : (j += 1) {
                self.net.layer2_weight[i][j] -= rate * (layer2_grad[i][j] + lambda * self.net.layer2_weight[i][j]);
            }
        }
    }
};
