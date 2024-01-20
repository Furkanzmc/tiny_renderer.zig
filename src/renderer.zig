const log = @import("std").log;
const debug = @import("std").debug;
const math = @import("std").math;
const types = @import("types.zig");
const Image = @import("stga").Image;

fn to_float(val: usize) f64 {
    return @floatFromInt(val);
}

fn swapPoints(point: *const types.Point) types.Point {
    return .{ .x = point.y, .y = point.x };
}

test "Test swap" {
    const testing = @import("std").testing;
    {
        var point: types.Point = .{ .x = 1, .y = 2 };
        point = swapPoints(&point);

        try testing.expectEqual(point.x, 2);
        try testing.expectEqual(point.y, 1);
    }
}

pub fn draw_line(image: *const Image, from: types.Point, to: types.Point, color: []const u8) void {
    var t: f16 = 0.0;
    while (t < 1.0) : (t += 0.01) {
        var val: f64 = @as(f64, @floatFromInt(to.x - from.x)) * t;
        const x: usize = @intCast(from.x + @as(usize, @intFromFloat(val)));

        val = @as(f64, @floatFromInt(to.y - from.y)) * t;
        const y: usize = @intCast(from.y + @as(usize, @intFromFloat(val)));
        image.set(x, y, color);
    }
}

pub fn draw_line_2nd(image: *const Image, from: types.Point, to: types.Point, color: []const u8) void {
    var x: usize = from.x;
    while (x < to.x) : (x += 1) {
        const t = to_float(x - from.x) / to_float(to.x - from.x);
        const y = @as(usize, @intFromFloat(to_float(from.y) * (1.0 - t) + to_float(to.y) * t));
        image.set(x, y, color);
    }
}

pub fn draw_line_3rd(image: *const Image, _from: types.Point, _to: types.Point, color: []const u8) void {
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
