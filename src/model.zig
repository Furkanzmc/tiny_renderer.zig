const ArrayList = @import("std").ArrayList;
const Vec3 = @import("types.zig").Vec3;
const io = @import("std").io;
const os = @import("std").os;
const fs = @import("std").fs;
const log = @import("std").log.err;
const mem = @import("std").mem;
const Allocator = mem.Allocator;
const fmt = @import("std").fmt;
const assert = @import("std").debug.assert;

const Vec3f = Vec3(3, f64);

const SliceNumberError = fmt.ParseFloatError || fmt.ParseIntError;
fn slice_number(comptime T: type, data: []const u8, start_index: u32, data_length: usize, terminator: u8) (SliceNumberError!struct { value: T, end_pos: u32 }) {
    var index = start_index;
    var first: i32 = -1;
    var last: i32 = -1;

    assert(start_index < data_length);

    while (index < data_length) : (index += 1) {
        const is_space = data[index] == @as(u8, ' ');
        const is_terminator = data[index] == terminator;
        if (first == -1 and !(is_space or is_terminator)) {
            first = @as(i32, @intCast(index));
        }

        const is_last_index = index == data_length - 1;
        if ((first > -1 and last == -1 and (is_space or is_terminator)) or is_last_index) {
            last = @as(i32, @intCast(if (is_last_index) index + 1 else index));
        }

        if (first > -1 and last > -1) {
            const f = @as(usize, @intCast(first));
            const l = @as(usize, @intCast(last));

            if (T == f64) {
                const val: T = try fmt.parseFloat(T, data[f..l]);
                return .{ .value = val, .end_pos = @as(u32, @intCast(last)) };
            }

            if (T == u64) {
                const val: T = try fmt.parseInt(T, data[f..l], 10);
                return .{ .value = val, .end_pos = @as(u32, @intCast(last)) };
            }

            @compileError("Cannot parse a float into a non-floating point type.");
        }
    }

    unreachable;
}

const ModelLineParseError = error{ParseError};
fn parseVertices(data: []const u8, data_length: usize) ModelLineParseError!Vec3f {
    var vec: Vec3f = Vec3f.init(.{ 0, 0, 0 });
    var end_pos: u32 = 0;
    var index: u4 = 0;
    while (end_pos < data_length) : (index += 1) {
        if (slice_number(f64, data, end_pos, data_length, ' ')) |result| {
            end_pos = result.end_pos;
            vec.set(index, result.value);
        } else |err| switch (err) {
            SliceNumberError.InvalidCharacter => return ModelLineParseError.ParseError,
            SliceNumberError.Overflow => return ModelLineParseError.ParseError,
        }
    }

    return vec;
}

fn parseFaces(data: []const u8, data_length: usize, allocator: Allocator) ModelLineParseError![]u64 {
    var vec = ArrayList(u64).init(allocator);
    var end_pos: u32 = 0;
    var index: u4 = 1;
    while (end_pos < data_length) {
        if (index != 1) {
            while (end_pos < data_length and data[end_pos] != ' ') : (end_pos += 1) {}
            index = 1;
            if (end_pos == data_length) {
                break;
            }
        } else if (slice_number(u64, data, end_pos, data_length, '/')) |result| {
            end_pos = result.end_pos;
            index += 1;
            if (vec.append(result.value)) |_| {} else |_| {}
        } else |err| switch (err) {
            SliceNumberError.InvalidCharacter => return ModelLineParseError.ParseError,
            SliceNumberError.Overflow => return ModelLineParseError.ParseError,
        }
    }

    return blk: {
        if (vec.toOwnedSlice()) |slice| {
            break :blk slice;
        } else |_| {
            break :blk ModelLineParseError.ParseError;
        }
    };
}

pub const Model = struct {
    const ReadError = error{ CannotRead, FileTooBig };

    verts: ArrayList(Vec3f),
    allocator: Allocator,

    pub fn init(allocator: Allocator) @This() {
        return .{ .verts = ArrayList(Vec3f).init(allocator), .allocator = allocator };
    }

    pub fn deinit(self: @This()) void {
        self.verts.deinit();
    }

    pub fn read(self: *Model, file_path: []const u8) (fs.File.OpenError || ReadError)!void {
        const file: fs.File = getFile: {
            if (fs.openFileAbsolute(file_path, .{ .mode = fs.File.OpenMode.read_only })) |file| {
                break :getFile file;
            } else |err| {
                return err;
            }
        };
        defer file.close();

        var buffer = ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        if (buffer.ensureTotalCapacity(32)) |_| {} else |_| {
            return ReadError.CannotRead;
        }

        self.verts = ArrayList(Vec3f).init(self.allocator);
        errdefer self.verts.deinit();

        const reader = file.reader();
        while (true) {
            if (reader.streamUntilDelimiter(buffer.writer(), '\n', null)) |_| {
                defer buffer.clearRetainingCapacity();

                if (mem.startsWith(u8, buffer.items, "v ")) {
                    if (parseVertices(buffer.items[2..], buffer.items.len - 2)) |vec| {
                        if (self.verts.append(vec)) |_| {} else |err| switch (err) {
                            error.OutOfMemory => return ReadError.FileTooBig,
                        }
                    } else |err| switch (err) {
                        ModelLineParseError.ParseError => log("Malformed line: {s}", .{buffer.items}),
                    }
                }
                if (mem.startsWith(u8, buffer.items, "f ")) {}
            } else |err| switch (err) {
                error.EndOfStream => break,
                else => return ReadError.CannotRead,
            }
        }
    }
};

test "slice_number" {
    const testing = @import("std").testing;

    try testing.expectError(SliceNumberError.InvalidCharacter, slice_number(f64, "asd", 0, 3, ' '));

    {
        const number_str = "-13 123 -33";
        var end_pos: u32 = 0;
        {
            const num = try slice_number(f64, number_str, 0, number_str.len, ' ');
            end_pos = num.end_pos;
            try testing.expectEqual(@as(f64, -13.0), num.value);
            try testing.expectEqual(@as(u32, 3), end_pos);
        }

        {
            const num = try slice_number(f64, number_str, end_pos, number_str.len, ' ');
            end_pos = num.end_pos;
            try testing.expectEqual(@as(f64, 123.0), num.value);
            try testing.expectEqual(@as(u32, 7), end_pos);
        }

        {
            const num = try slice_number(f64, number_str, end_pos, number_str.len, ' ');
            end_pos = num.end_pos;
            try testing.expectEqual(@as(f64, -33.0), num.value);
            try testing.expectEqual(number_str.len, end_pos);
        }
    }

    {
        const number_str = "3/2/1";
        var end_pos: u32 = 0;
        {
            const num = try slice_number(u64, number_str, 0, number_str.len, '/');
            end_pos = num.end_pos;
            try testing.expectEqual(@as(u64, 3), num.value);
            try testing.expectEqual(@as(u32, 1), end_pos);
        }

        {
            const num = try slice_number(u64, number_str, end_pos, number_str.len, '/');
            end_pos = num.end_pos;
            try testing.expectEqual(@as(u64, 2), num.value);
            try testing.expectEqual(@as(u32, 3), end_pos);
        }

        {
            const num = try slice_number(u64, number_str, end_pos, number_str.len, '/');
            end_pos = num.end_pos;
            try testing.expectEqual(@as(u64, 1), num.value);
            try testing.expectEqual(@as(u32, 5), end_pos);
        }
    }
}

test "parseVertices" {
    const testing = @import("std").testing;
    {
        const number_str = "-13 123 -33";
        const vec = try parseVertices(number_str, number_str.len);

        try testing.expectEqual(Vec3f.init(.{ -13.0, 123.0, -33.0 }), vec);
    }

    {
        const number_str = "3 3 3";
        const vec = try parseVertices(number_str, number_str.len);

        try testing.expectEqual(Vec3f.init(.{ 3, 3, 3 }), vec);
    }

    {
        const number_str = "0 0 0";
        const vec = try parseVertices(number_str, number_str.len);

        try testing.expectEqual(Vec3f.init(.{ 0, 0, 0 }), vec);
    }

    {
        const number_str = "0.68 0 0";
        const vec = try parseVertices(number_str, number_str.len);

        try testing.expectEqual(Vec3f.init(.{ 0.68, 0, 0 }), vec);
    }

    {
        const number_str = "  0   0        0";
        const vec = try parseVertices(number_str, number_str.len);

        try testing.expectEqual(Vec3f.init(.{ 0, 0, 0 }), vec);
    }
}

test "parseFaces" {
    const testing = @import("std").testing;
    {
        const number_str = "13/123/33 10/11/32 1/23/23";
        const vec = ArrayList(u64).fromOwnedSlice(testing.allocator, try parseFaces(number_str, number_str.len, testing.allocator));
        defer vec.deinit();

        try testing.expectEqual(@as(usize, 3), vec.items.len);

        try testing.expectEqual(@as(usize, 13), vec.items[0]);
        try testing.expectEqual(@as(usize, 10), vec.items[1]);
        try testing.expectEqual(@as(usize, 1), vec.items[2]);
    }

    {
        const number_str = "13/123/33 10/11/32 1/23/23 32/32/32";
        const vec = ArrayList(u64).fromOwnedSlice(testing.allocator, try parseFaces(number_str, number_str.len, testing.allocator));
        defer vec.deinit();

        try testing.expectEqual(@as(usize, 4), vec.items.len);

        try testing.expectEqual(@as(usize, 13), vec.items[0]);
        try testing.expectEqual(@as(usize, 10), vec.items[1]);
        try testing.expectEqual(@as(usize, 1), vec.items[2]);
        try testing.expectEqual(@as(usize, 32), vec.items[3]);
    }
}

test "Test Model init" {
    const testing = @import("std").testing;

    var model = Model.init(testing.allocator);
    defer model.deinit();

    try testing.expectEqual(@as(usize, 0), model.verts.capacity);

    const file_name = os.getenv("TINY_RENDERER_OBJ");
    if (file_name) |path| {
        try model.read(path);
        try testing.expectEqual(@as(usize, 4), model.verts.items.len);
        try testing.expectEqual(model.verts.items[0], Vec3f.init(.{ -1, -1, -1 }));
        try testing.expectEqual(model.verts.items[1], Vec3f.init(.{ 1, -1, -1 }));
        try testing.expectEqual(model.verts.items[2], Vec3f.init(.{ 1, -1, 1 }));
        try testing.expectEqual(model.verts.items[3], Vec3f.init(.{ -1, -1, 1 }));
    }
}
