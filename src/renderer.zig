const log = @import("std").log;
const debug = @import("std").debug;
const math = @import("std").math;
const types = @import("types.zig");
const Model = @import("model.zig").Model;
const Image = @import("stga").Image;
const Vec = @import("types.zig").Vec;
const Vec3f = Vec(3, f64);
const PointU = types.Point(u64);

fn to_float(val: usize) f64 {
    return @floatFromInt(val);
}

fn swapPoints(point: *const PointU) PointU {
    return .{ .x = point.y, .y = point.x };
}

test "Test swap" {
    const testing = @import("std").testing;
    {
        var point: PointU = .{ .x = 1, .y = 2 };
        point = swapPoints(&point);

        try testing.expectEqual(point.x, 2);
        try testing.expectEqual(point.y, 1);
    }
}

pub fn draw_line(image: *const Image, from: PointU, to: PointU, color: []const u8) void {
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

pub fn draw_line_3rd(image: *const Image, _from: PointU, _to: PointU, color: []const u8) void {
    debug.assert(_from.x < math.maxInt(usize));
    debug.assert(_from.y < math.maxInt(usize));
    debug.assert(_to.x < math.maxInt(usize));
    debug.assert(_to.y < math.maxInt(usize));

    var from = _from;
    var to = _to;

    const steep: bool = blk: {
        const l: i64 = math.absInt(@as(i64, @intCast(from.x)) - @as(i64, @intCast(to.x))) catch unreachable;
        const r: i64 = math.absInt(@as(i64, @intCast(from.y)) - @as(i64, @intCast(to.y))) catch unreachable;
        if (l < r) {
            from = swapPoints(&from);
            to = swapPoints(&to);
            break :blk true;
        }

        break :blk false;
    };

    if (from.x > to.x) {
        var tmp = from.x;
        from.x = to.x;
        to.x = tmp;

        tmp = from.y;
        from.y = to.y;
        to.y = tmp;
    }

    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const derror = blk: {
        const val = to_float(dy) / to_float(dx);
        break :blk if (val < 0) val * -1 else val;
    };
    var err: f64 = 0;
    var y = from.y;
    var x = from.x;
    while (x <= to.x) : (x += 1) {
        if (steep) {
            image.set(y, x, color);
        } else {
            image.set(x, y, color);
        }

        err += derror;
        const fdx: f64 = @floatFromInt(dx);
        if (err > fdx) {
            if (to.y > from.y) y += 1 else y -= 1;
            err -= fdx * 2.0;
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

            const x0 = @min(fwidth, (v0.get(0) + 1.0) * (fwidth / div));
            const y0 = @min(fheight, (v0.get(1) + 1.0) * (fheight / div));
            const x1 = @min(fwidth, (v1.get(0) + 1.0) * (fwidth / div));
            const y1 = @min(fheight, (v1.get(1) + 1.0) * (fheight / div));

            const from_pos: PointU = .{ .x = @intFromFloat(x0), .y = @intFromFloat(y0) };
            const to_pos: PointU = .{ .x = @intFromFloat(x1), .y = @intFromFloat(y1) };
            draw_line_3rd(image, from_pos, to_pos, &color);
        }
    }
}
