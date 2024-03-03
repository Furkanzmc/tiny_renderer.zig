const log = @import("std").log;
const assert = @import("std").debug.assert;
const math = @import("std").math;
const types = @import("types.zig");
const Model = @import("model.zig").Model;
const Image = @import("stga").Image;
const Vec = @import("types.zig").Vec;
const Vec3f = Vec(3, f64);
const PointU = types.Point(u64);

inline fn to_float(val: usize) f64 {
    return @floatFromInt(val);
}

inline fn swap(comptime T: type, left: *T, right: *T) void {
    var tmp = left.*;
    left.* = right.*;
    right.* = tmp;
}

test "Test swap" {
    const testing = @import("std").testing;
    {
        var x0: u32 = 3;
        var x1: u32 = 2;
        swap(u32, &x0, &x1);

        try testing.expectEqual(x0, 2);
        try testing.expectEqual(x1, 3);
    }
}

pub fn draw_line_slow(image: *const Image, from: PointU, to: PointU, color: []const u8) void {
    var t: f16 = 0.0;
    while (t < 1.0) : (t += 0.01) {
        var val: f64 = @as(f64, @floatFromInt(to.x - from.x)) * t;
        const x: usize = @intCast(from.x + @as(usize, @intFromFloat(val)));

        val = @as(f64, @floatFromInt(to.y - from.y)) * t;
        const y: usize = @intCast(from.y + @as(usize, @intFromFloat(val)));
        image.set(x, y, color);
    }
}

pub fn draw_line_2nd(image: *const Image, from: PointU, to: PointU, color: []const u8) void {
    var x: usize = from.x;
    while (x < to.x) : (x += 1) {
        const t = to_float(x - from.x) / to_float(to.x - from.x);
        const y = @as(usize, @intFromFloat(to_float(from.y) * (1.0 - t) + to_float(to.y) * t));
        image.set(x, y, color);
    }
}

pub fn draw_line(image: *const Image, _from: PointU, _to: PointU, color: []const u8) void {
    assert(_from.x < math.maxInt(usize));
    assert(_from.y < math.maxInt(usize));
    assert(_to.x < math.maxInt(usize));
    assert(_to.y < math.maxInt(usize));

    var from = _from;
    var to = _to;
    const is_steep: bool = blk: {
        const l: i64 = math.absInt(@as(i64, @intCast(from.x)) - @as(i64, @intCast(to.x))) catch unreachable;
        const r: i64 = math.absInt(@as(i64, @intCast(from.y)) - @as(i64, @intCast(to.y))) catch unreachable;
        if (l < r) {
            swap(u64, &from.x, &from.y);
            swap(u64, &to.x, &to.y);
            break :blk true;
        }

        break :blk false;
    };

    if (from.x > to.x) {
        swap(u64, &from.x, &to.x);
        swap(u64, &from.y, &to.y);
    }

    const dx: i64 = @as(i64, @intCast(to.x)) - @as(i64, @intCast(from.x));
    const dy: i64 = @as(i64, @intCast(to.y)) - @as(i64, @intCast(from.y));
    const derror: i64 = (if (dy < 0) dy * -1 else dy) * 2;
    var error2: i64 = 0;

    var x = from.x;
    var y = from.y;
    while (x <= to.x) : (x += 1) {
        if (is_steep) {
            image.set(y, x, color);
        } else {
            image.set(x, y, color);
        }

        error2 += derror;
        if (error2 > dx) {
            if (to.y > from.y) {
                y += 1;
            } else {
                y -= 1;
            }

            error2 -= dx * 2;
        }
    }
}

pub fn render_model(model: *const Model, image: *const Image, color: [4]u8) void {
    var face_index: u64 = 0;

    while (face_index < model.face_count()) : (face_index += 1) {
        const face: [3]u64 = model.face_vert(face_index);

        var vert_index: u4 = 0;
        while (vert_index < 3) : (vert_index += 1) {
            const v0: Vec3f = model.verts.items[face[vert_index]];
            const v1: Vec3f = model.verts.items[face[(vert_index + 1) % 3]];

            const div: f16 = 2.0;
            const fwidth: f64 = @floatFromInt(image.width);
            const fheight: f64 = @floatFromInt(image.height);

            const x0 = @min(fwidth - 1, (v0.get(0) + 1.0) * (fwidth / div));
            const y0 = @min(fheight - 1, (v0.get(1) + 1.0) * (fheight / div));
            const x1 = @min(fwidth - 1, (v1.get(0) + 1.0) * (fwidth / div));
            const y1 = @min(fheight - 1, (v1.get(1) + 1.0) * (fheight / div));

            const from_pos: PointU = .{ .x = @intFromFloat(x0), .y = @intFromFloat(y0) };
            const to_pos: PointU = .{ .x = @intFromFloat(x1), .y = @intFromFloat(y1) };
            draw_line(image, from_pos, to_pos, &color);
        }
    }
}
