const std = @import("std");
const Array = @import("array.zig").Array;
const renju = @import("renju.zig");
const Color = enum { None, Black, White };

var buffer: [400]u8 = undefined;
var allocator: std.heap.FixedBufferAllocator = undefined;
var board: Array(Color, 2) = undefined;
var player: Color = undefined;
var last_x: usize = undefined;
var last_y: usize = undefined;

export fn referee_init() void {
	allocator = std.heap.FixedBufferAllocator.init(buffer[0..]);
	board = Array(Color, 2).init(allocator.allocator(), .{15, 15}) catch @panic("Out of Memory");
	std.mem.set(Color, board.data, .None);
	player = Color.Black;
}

export fn referee_update(pos_x: c_int, pos_y: c_int) void {
	board.set(.{ @intCast(usize, pos_x), @intCast(usize, pos_y) }, player);
	player = if (player == Color.Black) Color.White else Color.Black;
	last_x = @intCast(usize, pos_x);
	last_y = @intCast(usize, pos_y);
}

export fn referee_check_win() c_int {
	return @boolToInt(renju.checkWin(&board, last_x, last_y));
}

export fn referee_check_legal() c_int {
	return @boolToInt(renju.checkLegal(&board, last_x, last_y));
}
