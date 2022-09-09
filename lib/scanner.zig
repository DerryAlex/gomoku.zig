const std = @import("std");
const trait = std.meta.trait;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const parseFloat = std.fmt.parseFloat;
const parseInt = std.fmt.parseInt;
const utf8ByteSequenceLength = std.unicode.utf8ByteSequenceLength;
const utf8Decode = std.unicode.utf8Decode;
const utf8Encode = std.unicode.utf8Encode;

pub fn isUnicodeSpace(codepoint: u21) bool {
    return switch (codepoint) {
        9...13, 32, 133, 160, 5760, 8192...8202, 8232...8233, 8239, 8287, 12288 => true,
        else => false,
    };
}

pub fn isUtf8Space(sequence: []u8) bool {
    return switch (sequence[0]) {
        9...13, 32 => true,
        194 => switch (sequence[1]) {
            133, 160 => true,
            else => false,
        },
        225 => switch (sequence[1]) {
            154 => switch (sequence[2]) {
                128 => true,
                else => false,
            },
            else => false,
        },
        226 => switch (sequence[1]) {
            128 => switch (sequence[2]) {
                128...138, 168...169, 175 => true,
                else => false,
            },
            129 => switch (sequence[2]) {
                159 => true,
                else => false,
            },
            else => false,
        },
        227 => switch (sequence[1]) {
            128 => switch (sequence[2]) {
                128 => true,
                else => false,
            },
            else => false,
        },
        else => false,
    };
}

pub fn scanner(internal_reader: anytype) Scanner(@TypeOf(internal_reader)) {
    return .{ .reader = internal_reader };
}

/// Input helper
pub fn Scanner(comptime Reader: type) type {
    return struct {
        reader: Reader,
        push_back: [4]u8 = .{ 0xFE, 0xFE, 0xFE, 0xFE },

        const Self = @This();

        /// Read a raw byte
        pub fn scanByte(self: *Self) !u8 {
            comptime var index = 0;
            inline while (index < self.push_back.len) : (index += 1) {
                if (self.push_back[index] <= 0xF7) { // 0xF8...0xFF are invalid UTF-8 bytes
                    const byte: u8 = self.push_back[index];
                    self.push_back[index] = 0xFE;
                    return byte;
                }
            }
            const byte: u8 = try self.reader.readByte();
            return byte;
        }

        /// Read a UTF-8 character
        /// CR LF and CR are handled
        pub fn scanUtf8Char(self: *Self, bytes: []u8) ![]u8 {
            bytes[0] = try self.scanByte();
            const length = try utf8ByteSequenceLength(bytes[0]);
            switch (length) {
                1 => {},
                2 => {
                    bytes[1] = try self.scanByte();
                },
                3 => {
                    bytes[1] = try self.scanByte();
                    bytes[2] = try self.scanByte();
                },
                4 => {
                    bytes[1] = try self.scanByte();
                    bytes[2] = try self.scanByte();
                    bytes[3] = try self.scanByte();
                },
                else => unreachable,
            }
            if (length == 0 and bytes[0] == '\r') {
                const next_byte: u8 = self.scanByte() catch |err| switch (err) {
                    error.EndOfStream => '\n',
                    else => {
                        return err;
                    },
                };
                if (next_byte != '\n') {
                    self.pushBackC(next_byte);
                }
                bytes[0] = '\n';
            }
            return bytes[0..length];
        }

        /// Read a Unicode character
        /// CR LF and CR are handled
        pub fn scanUnicodeChar(self: *Self) !u21 {
            var bytes: [4]u8 = undefined;
            const sequence = try self.scanUtf8Char(bytes[0..]);
            const codepoint = try utf8Decode(sequence);
            return codepoint;
        }

        // Only one pushback
        fn pushBackC(self: *Self, codepoint: u21) void {
            _ = utf8Encode(codepoint, self.push_back[0..]) catch unreachable;
        }

        fn pushBackS(self: *Self, sequence: []u8) void {
            for (sequence) |byte, i| {
                self.push_back[i] = byte;
            }
        }

        pub fn skipWhitespaces(self: *Self) !void {
            var codepoint: u21 = undefined;
            while (true) {
                codepoint = self.scanUnicodeChar() catch |err| {
                    switch (err) {
                        error.EndOfStream => {
                            return;
                        },
                        else => {
                            return err;
                        },
                    }
                };
                if (!isUnicodeSpace(codepoint)) {
                    break;
                }
            }
            self.pushBackC(codepoint);
        }

        const State = enum {
            EMPTY,
            SIGN,
            LEADING_ZERO,
            NORMAL_BIN,
            NORMAL_OCT,
            NORMAL_DEC,
            NORMAL_HEX,
            CONCAT_BIN,
            CONCAT_OCT,
            CONCAT_DEC,
            CONCAT_HEX,
            FRAC_NORMAL_DEC,
            FRAC_NORMAL_HEX,
            FRAC_CONCAT_DEC,
            FRAC_CONCAT_HEX,
            EXP,
            EXP_NORMAL,
            EXP_CONCAT,
        };

        fn scanNumber(self: *Self, number: []u8) !usize {
            var state: State = .EMPTY;
            var index: usize = 0;
            var codepoint: u21 = undefined;
            while (true) : (index += 1) {
                codepoint = self.scanUnicodeChar() catch |err| {
                    switch (err) {
                        error.EndOfStream => {
                            if (index == 0) {
                                return error.EndOfStream;
                            } else if (index > number.len) {
                                return error.StreamTooLong;
                            } else {
                                return index;
                            }
                        },
                        else => {
                            return err;
                        },
                    }
                };
                switch (state) {
                    .EMPTY => {
                        switch (codepoint) {
                            '+', '-' => {
                                state = .SIGN;
                            },
                            '0' => {
                                state = .LEADING_ZERO;
                            },
                            '1'...'9' => {
                                state = .NORMAL_DEC;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                    .SIGN => {
                        switch (codepoint) {
                            '0' => {
                                state = .LEADING_ZERO;
                            },
                            '1'...'9' => {
                                state = .NORMAL_DEC;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                    .LEADING_ZERO => {
                        switch (codepoint) {
                            'b' => {
                                state = .CONCAT_BIN;
                            },
                            'o' => {
                                state = .CONCAT_OCT;
                            },
                            'x' => {
                                state = .CONCAT_HEX;
                            },
                            '0'...'9' => {
                                state = .NORMAL_DEC;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                    .NORMAL_BIN => {
                        switch (codepoint) {
                            '0'...'1' => {
                                state = .NORMAL_BIN;
                            },
                            '_' => {
                                state = .CONCAT_BIN;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                    .NORMAL_OCT => {
                        switch (codepoint) {
                            '0'...'7' => {
                                state = .NORMAL_OCT;
                            },
                            '_' => {
                                state = .CONCAT_OCT;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                    .NORMAL_DEC => {
                        switch (codepoint) {
                            '0'...'9' => {
                                state = .NORMAL_DEC;
                            },
                            '_' => {
                                state = .CONCAT_DEC;
                            },
                            '.' => {
                                state = .FRAC_CONCAT_DEC;
                            },
                            'e' => {
                                state = .EXP;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                    .NORMAL_HEX => {
                        switch (codepoint) {
                            '0'...'9', 'A'...'F', 'a'...'f' => {
                                state = .NORMAL_HEX;
                            },
                            '_' => {
                                state = .CONCAT_HEX;
                            },
                            '.' => {
                                state = .FRAC_CONCAT_HEX;
                            },
                            'p' => {
                                state = .EXP;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                    .CONCAT_BIN => {
                        switch (codepoint) {
                            '0'...'1' => {
                                state = .NORMAL_BIN;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                    .CONCAT_OCT => {
                        switch (codepoint) {
                            '0'...'7' => {
                                state = .NORMAL_OCT;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                    .CONCAT_DEC => {
                        switch (codepoint) {
                            '0'...'9' => {
                                state = .NORMAL_DEC;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                    .CONCAT_HEX => {
                        switch (codepoint) {
                            '0'...'9', 'A'...'F', 'a'...'f' => {
                                state = .NORMAL_HEX;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                    .FRAC_NORMAL_DEC => {
                        switch (codepoint) {
                            '0'...'9' => {
                                state = .FRAC_NORMAL_DEC;
                            },
                            '_' => {
                                state = .FRAC_CONCAT_DEC;
                            },
                            'e' => {
                                state = .EXP;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                    .FRAC_NORMAL_HEX => {
                        switch (codepoint) {
                            '0'...'9', 'A'...'F', 'a'...'f' => {
                                state = .FRAC_NORMAL_HEX;
                            },
                            '_' => {
                                state = .FRAC_CONCAT_HEX;
                            },
                            'p' => {
                                state = .EXP;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                    .FRAC_CONCAT_DEC => {
                        switch (codepoint) {
                            '0'...'9' => {
                                state = .FRAC_NORMAL_DEC;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                    .FRAC_CONCAT_HEX => {
                        switch (codepoint) {
                            '0'...'9', 'A'...'F', 'a'...'f' => {
                                state = .FRAC_NORMAL_HEX;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                    .EXP => {
                        switch (codepoint) {
                            '+', '-' => {
                                state = .EXP_CONCAT;
                            },
                            '0'...'9' => {
                                state = .EXP_NORMAL;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                    .EXP_NORMAL => {
                        switch (codepoint) {
                            '0'...'9' => {
                                state = .EXP_NORMAL;
                            },
                            '_' => {
                                state = .EXP_CONCAT;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                    .EXP_CONCAT => {
                        switch (codepoint) {
                            '0'...'9' => {
                                state = .EXP_NORMAL;
                            },
                            else => {
                                break;
                            },
                        }
                    },
                }
                if (index < number.len) number[index] = @truncate(u8, codepoint);
            }
            self.pushBackC(codepoint);
            if (index == 0) {
                return error.InvalidCharacter;
            }
            if (index > number.len) {
                return error.StreamTooLong;
            }
            return index;
        }

        pub fn scanInt(self: *Self, comptime Int: type) !Int {
            const BUF_LEN = 42;
            var buf: [BUF_LEN]u8 = undefined;
            const length = try self.scanNumber(buf[0..]);
            const x = try parseInt(Int, buf[0..length], 0);
            return x;
        }

        pub fn scanFloat(self: *Self, comptime Float: type) !Float {
            const BUF_LEN = 24;
            var buf: [BUF_LEN]u8 = undefined;
            const length = try self.scanNumber(buf[0..]);
            const x = try parseFloat(Float, buf[0..length]);
            return x;
        }

        pub fn scanUtf8String(self: *Self, string: []u8) ![]u8 {
            var index: usize = 0;
            var bytes: [4]u8 = undefined;
            var sequence: []u8 = undefined;
            while (true) {
                sequence = self.scanUtf8Char(bytes[0..]) catch |err| switch (err) {
                    error.EndOfStream => {
                        if (index == 0) {
                            return error.EndOfStream;
                        } else {
                            return string[0..index];
                        }
                    },
                    else => {
                        return err;
                    },
                };
                if (isUtf8Space(sequence)) {
                    break;
                }
                if (index + sequence.len > string.len) {
                    self.pushBackS(sequence);
                    return error.StreamTooLong;
                }
                for (sequence) |byte| {
                    string[index] = byte;
                    index += 1;
                }
            }
            self.pushBackS(sequence);
            return string[0..index];
        }

        pub fn scanUtf8StringAlloc(self: *Self, allocator: Allocator) ![]u8 {
            var array_list = ArrayList(u8).init(allocator);
            errdefer array_list.deinit();
            var bytes: [4]u8 = undefined;
            var sequence: []u8 = undefined;
            while (true) {
                sequence = self.scanUtf8Char(bytes[0..]) catch |err| switch (err) {
                    error.EndOfStream => {
                        if (array_list.capacity == 0) {
                            return error.EndOfStream;
                        } else {
                            return array_list.toOwnedSlice();
                        }
                    },
                    else => {
                        return err;
                    },
                };
                if (isUtf8Space(sequence)) {
                    break;
                }
                try array_list.appendSlice(sequence);
            }
            self.pushBackS(sequence);
            return array_list.toOwnedSlice();
        }

        pub fn scanUnicodeString(self: *Self, string: []u21) ![]u21 {
            var index: usize = 0;
            var codepoint: u21 = undefined;
            while (index <= string.len) : (index += 1) {
                codepoint = self.scanUnicodeChar() catch |err| switch (err) {
                    error.EndOfStream => {
                        if (index == 0) {
                            return error.EndOfStream;
                        } else {
                            return string[0..index];
                        }
                    },
                    else => {
                        return err;
                    },
                };
                if (isUnicodeSpace(codepoint)) {
                    break;
                }
                if (index == string.len) {
                    self.pushBackC(codepoint);
                    return error.StreamTooLong;
                }
                string[index] = codepoint;
            }
            self.pushBackC(codepoint);
            return string[0..index];
        }

        pub fn scanUnicodeStringAlloc(self: *Self, allocator: Allocator) ![]u21 {
            var array_list = ArrayList(u21).init(allocator);
            errdefer array_list.deinit();
            var codepoint: u21 = undefined;
            while (true) {
                codepoint = self.scanUnicodeChar() catch |err| switch (err) {
                    error.EndOfStream => {
                        if (array_list.capacity == 0) {
                            return error.EndOfStream;
                        } else {
                            return array_list.toOwnedSlice();
                        }
                    },
                    else => {
                        return err;
                    },
                };
                if (isUnicodeSpace(codepoint)) {
                    break;
                }
                try array_list.append(codepoint);
            }
            self.pushBackC(codepoint);
            return array_list.toOwnedSlice();
        }

        pub fn scan(self: *Self, comptime T: type) !T {
            switch (@typeInfo(T)) {
                .Int => {
                    return try self.scanInt(T);
                },
                .Float => {
                    return try self.scanFloat(T);
                },
                else => {
                    if (comptime trait.hasFn("scan")(T)) {
                        return try T.scan(self);
                    } else {
                        @compileError("`scan(scanner) !Self` should be implemented");
                    }
                },
            }
        }

        pub fn scanAlloc(self: *Self, comptime T: type, allocator: Allocator) !T {
            if (comptime trait.hasFn("scanAlloc")(T)) {
                return try T.scanAlloc(self, allocator);
            } else {
                @compileError("`scanAlloc(scanner, allocator) !Self` should be implemented");
            }
        }
    };
}
