const std = @import("std");
const Allocator = std.mem.Allocator;

/// Multidimensional array whose exact size is only known at runtime
pub fn Array(comptime T: type, comptime dimensions: comptime_int) type {
    return struct {
        const Dimension = if (dimensions == 0) []const usize else [dimensions]usize;
        dimension: Dimension,
        data: []T,
        allocator: Allocator,

        const Self = @This();

        pub fn init(allocator: Allocator, dimension: Dimension) error{OutOfMemory}!Self {
            var dimension_dupe: Dimension = undefined;
            if (dimensions == 0) {
                dimension_dupe = try allocator.dupe(usize, dimension);
            } else {
                std.mem.copy(usize, dimension_dupe[0..], dimension[0..]);
            }
            var size: usize = 1;
            for (dimension) |length| {
                size *= length;
            }
            var data = try allocator.alloc(T, size);
            return Self{ .dimension = dimension_dupe, .data = data, .allocator = allocator };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.data);
            if (dimensions == 0) {
                self.allocator.free(self.dimension);
            }
        }

        fn getIndex(self: *const Self, index: Dimension) usize {
            std.debug.assert(self.dimension.len == index.len);
            var where: usize = 0;
            for (self.dimension) |length, i| {
                std.debug.assert(index[i] < length);
                where = where * length + index[i];
            }
            return where;
        }

        pub fn get(self: *const Self, index: Dimension) T {
            return self.data[self.getIndex(index)];
        }

        pub fn set(self: *Self, index: Dimension, item: T) void {
            self.data[self.getIndex(index)] = item;
        }
    };
}
