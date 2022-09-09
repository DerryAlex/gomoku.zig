const std = @import("std");
const readInt = std.mem.readIntSliceLittle;
const BoundedArray = std.BoundedArray;
const Board = @import("board.zig").Board;

const nnue_data = @embedFile("nnue.bin");

const DataType = i16;
const DataVecN = 128 / @bitSizeOf(DataType);
const DataVec = @Vector(DataVecN, DataType);

fn __quantmoid(x: DataVec) DataVec {
    const v0 = @splat(DataVecN, @as(DataType, 0));
    const v126 = @splat(DataVecN, @as(DataType, 126));
    const v127 = @splat(DataVecN, @as(DataType, 127));
    const x_sgn = x < v0;
    const x_abs = @select(DataType, x_sgn, -x, x);
    const xx = @select(DataType, x_abs < v127, x, v127) - v127;
    const yy = (xx * xx) >> @splat(DataVecN, @as(u4, 8));
    return @select(DataType, x_sgn, v126 - yy, yy);
}

pub fn quantmoid(comptime input_size: comptime_int, input: [input_size]DataType, output: []DataType) void {
    if (comptime input_size % DataVecN != 0) {
        @compileError("");
    }
    var index: usize = 0;
    while (index < input_size) : (index += DataVecN) {
        output[index..][0..DataVecN].* = __quantmoid(input[index..][0..DataVecN].*);
    }
}

pub fn linear(comptime input_size: comptime_int, comptime output_size: comptime_int, input: [input_size]DataType, output: []DataType, weight: [input_size][output_size]DataType, bias: [output_size]DataType) void {
    if (comptime output_size % DataVecN != 0) {
        @compileError("");
    }
    var regs: [output_size / DataVecN]DataVec = [_]DataVec{@splat(DataVecN, @as(DataType, 0))} ** (output_size / DataVecN);
    var k: usize = 0;
    var index: usize = 0;
    while (index < output_size) : (index += DataVecN) {
        regs[k] = bias[index..][0..DataVecN].*;
        k += 1;
    }
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

pub fn accumulate(comptime input_size: comptime_int, comptime output_size: comptime_int, activate: []const usize, deactivate: []const usize, output: []DataType, weight: [input_size][output_size]DataType) void {
    var regs: [output_size / DataVecN]DataVec = [_]DataVec{@splat(DataVecN, @as(DataType, 0))} ** (output_size / DataVecN);
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

pub const Nnue = struct { // TODO: backward
    const LAYER0_INPUT_SIZE = 512;
    const LAYER0_OUTPUT_SIZE = 32;
    const LAYER1_INPUT_SIZE = LAYER0_OUTPUT_SIZE;
    const LAYER1_OUTPUT_SIZE = 32;
    const LAYER2_INPUT_SIZE = LAYER1_OUTPUT_SIZE;
    const LAYER2_OUTPUT_SIZE = 8;
    const LAYER3_INPUT_SIZE = LAYER2_OUTPUT_SIZE;
    const LAYER3_OUTPUT_SIZE = 1;

    layer0: [LAYER0_INPUT_SIZE]DataType = [_]DataType{0} ** LAYER0_INPUT_SIZE,
    hidden0: [LAYER0_OUTPUT_SIZE]DataType,
    layer1: [LAYER1_INPUT_SIZE]DataType = undefined,
    hidden1: [LAYER0_OUTPUT_SIZE]DataType = undefined,
    layer2: [LAYER2_INPUT_SIZE]DataType = undefined,
    hidden2: [LAYER2_OUTPUT_SIZE]DataType = undefined,
    layer3: [LAYER3_INPUT_SIZE]DataType = undefined,
    result: DataType = undefined,

    layer0_weight: [LAYER0_INPUT_SIZE][LAYER0_OUTPUT_SIZE]DataType,
    layer0_bias: [LAYER0_OUTPUT_SIZE]DataType,
    layer1_weight: [LAYER1_INPUT_SIZE][LAYER1_OUTPUT_SIZE]DataType,
    layer1_bias: [LAYER1_OUTPUT_SIZE]DataType,
    layer2_weight: [LAYER2_INPUT_SIZE][LAYER2_OUTPUT_SIZE]DataType,
    layer2_bias: [LAYER2_OUTPUT_SIZE]DataType,
    layer3_weight: [LAYER3_INPUT_SIZE][LAYER3_OUTPUT_SIZE]DataType,
    result_bias: DataType,

    const Self = @This();

    pub fn init() Self {
        var index: usize = 0;
        var layer0_weight: [LAYER0_INPUT_SIZE][LAYER0_OUTPUT_SIZE]DataType = undefined;
        var layer0_bias: [LAYER0_OUTPUT_SIZE]DataType = undefined;
        var layer1_weight: [LAYER1_INPUT_SIZE][LAYER1_OUTPUT_SIZE]DataType = undefined;
        var layer1_bias: [LAYER1_OUTPUT_SIZE]DataType = undefined;
        var layer2_weight: [LAYER2_INPUT_SIZE][LAYER2_OUTPUT_SIZE]DataType = undefined;
        var layer2_bias: [LAYER2_OUTPUT_SIZE]DataType = undefined;
        var layer3_weight: [LAYER3_INPUT_SIZE][LAYER3_OUTPUT_SIZE]DataType = undefined;
        var result_bias: DataType = undefined;
        var i: usize = 0;
        while (i < LAYER0_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER0_OUTPUT_SIZE) : (j += 1) {
                layer0_weight[i][j] = readInt(DataType, nnue_data[index..]);
                index += @sizeOf(DataType);
            }
        }
        i = 0;
        while (i < LAYER0_OUTPUT_SIZE) : (i += 1) {
            layer0_bias[i] = readInt(DataType, nnue_data[index..]);
            index += @sizeOf(DataType);
        }
        i = 0;
        while (i < LAYER1_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER1_OUTPUT_SIZE) : (j += 1) {
                layer1_weight[i][j] = readInt(DataType, nnue_data[index..]);
                index += @sizeOf(DataType);
            }
        }
        i = 0;
        while (i < LAYER1_OUTPUT_SIZE) : (i += 1) {
            layer1_bias[i] = readInt(DataType, nnue_data[index..]);
            index += @sizeOf(DataType);
        }
        i = 0;
        while (i < LAYER2_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER2_OUTPUT_SIZE) : (j += 1) {
                layer2_weight[i][j] = readInt(DataType, nnue_data[index..]);
                index += @sizeOf(DataType);
            }
        }
        i = 0;
        while (i < LAYER2_OUTPUT_SIZE) : (i += 1) {
            layer2_bias[i] = readInt(DataType, nnue_data[index..]);
            index += @sizeOf(DataType);
        }
        i = 0;
        while (i < LAYER3_INPUT_SIZE) : (i += 1) {
            var j: usize = 0;
            while (j < LAYER3_OUTPUT_SIZE) : (j += 1) {
                layer3_weight[i][j] = readInt(DataType, nnue_data[index..]);
                index += @sizeOf(DataType);
            }
        }
        result_bias = readInt(DataType, nnue_data[index..]);
        index += @sizeOf(DataType);
        std.debug.assert(index == nnue_data.len);
        return Self{ .hidden0 = layer0_bias, .layer0_weight = layer0_weight, .layer0_bias = layer0_bias, .layer1_weight = layer1_weight, .layer1_bias = layer1_bias, .layer2_weight = layer2_weight, .layer2_bias = layer2_bias, .layer3_weight = layer3_weight, .result_bias = result_bias };
    }

    // Lazy update
    pub fn update(self: *Self, board: *const Board) void {
        const width = 15;
        const height = 15;
        var i: usize = 0;
        var activate = BoundedArray(usize, width * height).init(0) catch unreachable;
        var deactivate = BoundedArray(usize, width * height).init(0) catch unreachable;
        while (i < width) : (i += 1) {
            var j: usize = 0;
            while (j < height) : (j += 1) {
                const color = board.get(.{i, j});
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
        accumulate(LAYER0_INPUT_SIZE, LAYER0_OUTPUT_SIZE, activate.slice(), deactivate.slice(), self.hidden0[0..], self.layer0_weight);
    }

    pub fn evaluate(self: *Self, board: *const Board) DataType {
        self.update(board);
        // linear(LAYER0_INPUT_SIZE, LAYER0_OUTPUT_SIZE, self.layer0, self.hidden0[0..], self.layer0_weight, self.layer0_bias);
        // quantmoid(LAYER0_OUTPUT_SIZE, self.hidden0, self.layer1[0..]);
        linear(LAYER1_INPUT_SIZE, LAYER1_OUTPUT_SIZE, self.layer1, self.hidden1[0..], self.layer1_weight, self.layer1_bias);
        quantmoid(LAYER1_OUTPUT_SIZE, self.hidden1, self.layer2[0..]);
        linear(LAYER2_INPUT_SIZE, LAYER2_OUTPUT_SIZE, self.layer2, self.hidden2[0..], self.layer2_weight, self.layer2_bias);
        quantmoid(LAYER2_OUTPUT_SIZE, self.hidden2, self.layer3[0..]);

        // Unoptimized layer3(No SIMD), no quantmoid
        self.result = self.result_bias;
        for (self.layer3) |val, i| {
            self.result = self.result + val * self.layer3_weight[i][0];
        }

        return self.result;
    }
};
