pub const Point = struct { x: usize, y: usize };
pub const Size = struct { width: usize, height: usize };
const assert = @import("std").debug.assert;

pub fn Vec(comptime N: u8, comptime T: type) type {
    return struct {
        const Self = @This();

        data: [N]T,

        pub fn init(initial: [N]T) Self {
            return .{.data=initial};
        }

        pub fn get(self: *const Self, index: u8) T {
            return self.data[index];
        }

        pub fn set(self: *Self, index: u8, value: T) void {
            self.data[index] = value;
        }

        pub fn equals(self: *Self, other: *const Self) void {
            assert(self.data.len == other.data.len);

            var index: u8 = 0;
            var equal = true;
            while(index < self.data.len) : (index += 1) {
                equal &= self.data[index] == other.data[index];
            }

            return equal;
        }

        pub fn add(self: *Self, other: Self) void {
            assert(self.data.len == other.data.len);

            var index: u8 = 0;
            while(index < self.data.len) : (index += 1) {
                self.data[index] += other.data[index];
            }
        }

        pub fn subtract(self: *Self, other: Self) void {
            assert(self.data.len == other.data.len);

            var index: u8 = 0;
            while(index < self.data.len) : (index += 1) {
                self.data[index] -= other.data[index];
            }
        }
    };
}

test "Vec" {
    const testing = @import("std").testing;

    var vec1 = Vec(3, i32).init(.{0,0,0});
    try testing.expectEqual(vec1.get(0), 0);

    vec1.set(0, 1);

    var vec2 = Vec(3, i32).init(.{0,0,0});
    vec2.set(0, 31);
    vec2.add(vec1);

    try testing.expectEqual(vec2.get(0), 32);
}
