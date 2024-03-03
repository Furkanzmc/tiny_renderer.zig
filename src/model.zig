const ArrayList = @import("std").ArrayList;
const Vec = @import("types.zig").Vec;
const io = @import("std").io;
const os = @import("std").os;
const fs = @import("std").fs;
const process = @import("std").process;
const log = @import("std").log;
const mem = @import("std").mem;
const Allocator = mem.Allocator;
const fmt = @import("std").fmt;
const assert = @import("std").debug.assert;
const builtin = @import("builtin");
const asAbsolutePath = @import("testUtils.zig").asAbsolutePath;

const Vec3f = Vec(3, f64);

// FIXME: Windows code doesn't work.
const LineEnding = blk: {
    if (builtin.os.tag == .windows) {
        break :blk '\r';
    }

    break :blk '\n';
};

pub const SliceNumberError = fmt.ParseFloatError || fmt.ParseIntError;
pub const ReadError = error{ CannotRead, FileTooBig };

const ReadLineState = struct {
    allocator: Allocator,
    file_path: []const u8,
    buffer: ArrayList(u8),
    file: fs.File,
    linenr: u64,
    current_line: []u8,
    end_of_stream: bool,

    pub fn init(allocator: Allocator, file_path: []const u8) (fs.File.OpenError!@This()) {
        const file: fs.File = redFile: {
            if (fs.openFileAbsolute(file_path, .{ .mode = fs.File.OpenMode.read_only })) |file| {
                break :redFile file;
            } else |err| {
                return err;
            }
        };
        var buffer = ArrayList(u8).init(allocator);
        if (buffer.ensureTotalCapacity(32)) |_| {} else |_| {
            return fs.File.OpenError.FileTooBig;
        }

        return .{ .allocator = allocator, .file_path = file_path, .buffer = buffer, .file = file, .linenr = 0, .current_line = "", .end_of_stream = false };
    }

    pub fn deinit(self: @This()) void {
        self.buffer.deinit();
        self.file.close();
        self.allocator.free(self.current_line);
    }
};

fn read_line(state: *ReadLineState) (fs.File.OpenError || ReadError)!void {
    if (state.file.reader().streamUntilDelimiter(state.buffer.writer(), LineEnding, null)) |_| {
        state.linenr += 1;
        if (state.allocator.alloc(u8, state.buffer.items.len)) |memory| {
            if (state.current_line.len != 0) {
                state.allocator.free(state.current_line);
            }

            state.current_line = memory;
        } else |_| {
            return ReadError.CannotRead;
        }

        @memcpy(state.current_line, state.buffer.items);
        state.buffer.clearRetainingCapacity();
    } else |err| switch (err) {
        error.EndOfStream => {
            state.end_of_stream = true;
            return;
        },
        else => return ReadError.CannotRead,
    }
}

fn slice_number(comptime T: type, data: []const u8, start_index: u32, data_length: usize, terminator: u8) (SliceNumberError!struct { value: T, end_pos: u32 }) {
    assert(start_index < data_length);

    var index = start_index;
    var first: i32 = -1;
    var last: i32 = -1;

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
            const current_char = data[f..l];

            if (T == f64) {
                const val: T = try fmt.parseFloat(T, current_char);
                return .{ .value = val, .end_pos = @as(u32, @intCast(last)) };
            }

            if (T == u64) {
                const val: T = try fmt.parseInt(T, current_char, 10);
                return .{ .value = val, .end_pos = @as(u32, @intCast(last)) };
            }

            @compileError("Cannot parse a float into a non-floating point type.");
        }
    }

    unreachable;
}

const ModelLineParseError = error{ ParseError, InvalidCharacter };

/// Parses a given line from an .obj file.
fn parseVertices(data: []const u8) ModelLineParseError!Vec3f {
    assert(mem.startsWith(u8, data, "v "));

    const number_line = data[2..];
    var vec: Vec3f = Vec3f.init(.{ 0, 0, 0 });
    var end_pos: u32 = 0;
    var index: u4 = 0;
    while (end_pos < number_line.len) : (index += 1) {
        if (slice_number(f64, number_line, end_pos, number_line.len, ' ')) |result| {
            end_pos = result.end_pos;
            vec.set(index, result.value);
        } else |err| switch (err) {
            SliceNumberError.InvalidCharacter => return ModelLineParseError.InvalidCharacter,
            SliceNumberError.Overflow => return ModelLineParseError.ParseError,
        }
    }

    return vec;
}

fn parseFaces(line: []const u8) (ModelLineParseError || fmt.ParseIntError)!struct { verts: [3]u64, tex: [3]u64, nrm: [3]u64 } {
    var verts: [3]u64 = .{ 0, 0, 0 };
    var tex: [3]u64 = .{ 0, 0, 0 };
    var nrm: [3]u64 = .{ 0, 0, 0 };

    var it = mem.split(u8, line, " ");
    var iteration: u4 = 0;
    while (it.next()) |numbers| {
        if (numbers.len == 0) {
            continue;
        }

        if (mem.eql(u8, numbers, " ")) {
            continue;
        }

        assert(iteration < 3);

        var valIt = mem.split(u8, numbers, "/");
        var v_type: u4 = 0;
        while (valIt.next()) |number| {
            assert(v_type < 3);

            if (number.len > 0) {
                const val = try fmt.parseInt(u64, number, 10);
                switch (v_type) {
                    0 => verts[iteration] = val,
                    1 => tex[iteration] = val,
                    2 => nrm[iteration] = val,
                    else => unreachable,
                }
            }

            v_type += 1;
        }

        iteration += 1;
    }

    return .{ .verts = verts, .tex = tex, .nrm = nrm };
}

pub const Model = struct {
    verts: ArrayList(Vec3f),
    face_verts: ArrayList([3]u64),
    face_tex: ArrayList([3]u64),
    face_nrm: ArrayList([3]u64),
    allocator: Allocator,

    pub fn init(allocator: Allocator) @This() {
        return .{ .verts = ArrayList(Vec3f).init(allocator), .face_verts = ArrayList([3]u64).init(allocator), .face_tex = ArrayList([3]u64).init(allocator), .face_nrm = ArrayList([3]u64).init(allocator), .allocator = allocator };
    }

    pub fn deinit(self: @This()) void {
        self.verts.deinit();
        self.face_verts.deinit();
        self.face_tex.deinit();
        self.face_nrm.deinit();
    }

    pub fn face_vert(self: @This(), index: u64) [3]u64 {
        assert(index < self.face_verts.items.len);

        var face = self.face_verts.items[index];
        face[0] = if (face[0] > 0) face[0] - 1 else face[0];
        face[1] = if (face[1] > 0) face[1] - 1 else face[1];
        face[2] = if (face[2] > 0) face[2] - 1 else face[2];
        return face;
    }

    pub fn face_count(self: @This()) u64 {
        return self.face_verts.items.len;
    }

    pub fn read(self: *Model, file_path: []const u8) (fs.File.OpenError || ReadError || ModelLineParseError)!void {
        var state = try ReadLineState.init(self.allocator, file_path);
        defer state.deinit();
        errdefer state.deinit();

        while (!state.end_of_stream) {
            try read_line(&state);
            if (state.end_of_stream) {
                break;
            }

            const line = state.current_line;
            if (mem.startsWith(u8, line, "v ")) {
                if (parseVertices(line)) |vec| {
                    if (self.verts.append(vec)) |_| {} else |err| switch (err) {
                        error.OutOfMemory => return ReadError.FileTooBig,
                    }
                } else |err| switch (err) {
                    ModelLineParseError.InvalidCharacter => log.err("Invalid character on line {}: {s}", .{ state.linenr, line }),
                    ModelLineParseError.ParseError => log.err("Parse error on line {}: {s}", .{ state.linenr, line }),
                }
            } else if (mem.startsWith(u8, line, "f ")) {
                if (parseFaces(line[2..])) |face| {
                    if (self.face_verts.append(face.verts)) |_| {} else |err| switch (err) {
                        error.OutOfMemory => return ReadError.FileTooBig,
                    }

                    if (self.face_tex.append(face.tex)) |_| {} else |err| switch (err) {
                        error.OutOfMemory => return ReadError.FileTooBig,
                    }

                    if (self.face_nrm.append(face.nrm)) |_| {} else |err| switch (err) {
                        error.OutOfMemory => return ReadError.FileTooBig,
                    }
                } else |err| switch (err) {
                    ModelLineParseError.InvalidCharacter => log.err("Invalid character on line {}: {s}", .{ state.linenr, line }),
                    ModelLineParseError.ParseError => log.err("Parse error on line {}: {s}", .{ state.linenr, line }),
                    fmt.ParseIntError.Overflow => log.err("Overflow with number on line {}: {s}", .{ state.linenr, line }),
                }
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
        const number_str = "-0.000581696 -0.734665 -0.623267";
        var end_pos: u32 = 0;
        {
            const num = try slice_number(f64, number_str, 0, number_str.len, ' ');
            end_pos = num.end_pos;
            try testing.expectEqual(@as(f64, -0.000581696), num.value);
        }

        {
            const num = try slice_number(f64, number_str, end_pos, number_str.len, ' ');
            end_pos = num.end_pos;
            try testing.expectEqual(@as(f64, -0.734665), num.value);
        }

        {
            const num = try slice_number(f64, number_str, end_pos, number_str.len, ' ');
            end_pos = num.end_pos;
            try testing.expectEqual(@as(f64, -0.623267), num.value);
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

test "Test slice_number with file" {
    const testing = @import("std").testing;

    const objFile = asAbsolutePath("./test_assets/slice_number.obj", testing.allocator);
    try testing.expect(objFile.len > 0);

    var state = try ReadLineState.init(testing.allocator, objFile);
    defer state.deinit();

    defer testing.allocator.free(objFile);
    while (state.end_of_stream == false) {
        try read_line(&state);
        // Exclude `v ` from the string.
        const number_str = state.current_line[2..];
        var end_pos: u32 = 0;
        {
            const num = try slice_number(f64, number_str, 0, number_str.len, ' ');
            end_pos = num.end_pos;
            try testing.expectEqual(@as(f64, -0.000581696), num.value);
        }

        {
            const num = try slice_number(f64, number_str, end_pos, number_str.len, ' ');
            end_pos = num.end_pos;
            try testing.expectEqual(@as(f64, -0.734665), num.value);
        }

        {
            const num = try slice_number(f64, number_str, end_pos, number_str.len, ' ');
            end_pos = num.end_pos;
            try testing.expectEqual(@as(f64, -0.623267), num.value);
        }
    }
}

test "parseVertices" {
    const testing = @import("std").testing;
    {
        const number_str = "v    -13 123 -33";
        const vec = try parseVertices(number_str);

        try testing.expectEqual(Vec3f.init(.{ -13.0, 123.0, -33.0 }), vec);
    }

    {
        const number_str = "v -0.000581696 -0.734665 -0.623267";
        const vec = try parseVertices(number_str);

        try testing.expectEqual(Vec3f.init(.{ -0.000581696, -0.734665, -0.623267 }), vec);
    }

    {
        const number_str = "v 3 3 3";
        const vec = try parseVertices(number_str);

        try testing.expectEqual(Vec3f.init(.{ 3, 3, 3 }), vec);
    }

    {
        const number_str = "v 0 0 0";
        const vec = try parseVertices(number_str);

        try testing.expectEqual(Vec3f.init(.{ 0, 0, 0 }), vec);
    }

    {
        const number_str = "v 0.68 0 0";
        const vec = try parseVertices(number_str);

        try testing.expectEqual(Vec3f.init(.{ 0.68, 0, 0 }), vec);
    }

    {
        const number_str = "v  0   0        0";
        const vec = try parseVertices(number_str);

        try testing.expectEqual(Vec3f.init(.{ 0, 0, 0 }), vec);
    }

    {
        const objFile = asAbsolutePath("./test_assets/slice_number.obj", testing.allocator);
        try testing.expect(objFile.len > 0);

        var state = try ReadLineState.init(testing.allocator, objFile);
        defer state.deinit();

        defer testing.allocator.free(objFile);
        while (state.end_of_stream == false) {
            try read_line(&state);
            const vec = try parseVertices(state.current_line);

            try testing.expectEqual(Vec3f.init(.{ -0.000581696, -0.734665, -0.623267 }), vec);
        }
    }

    {
        const objFile = asAbsolutePath("./tutorial/obj/african_head.obj", testing.allocator);
        try testing.expect(objFile.len > 0);

        var state = try ReadLineState.init(testing.allocator, objFile);
        defer state.deinit();

        defer testing.allocator.free(objFile);
        while (state.linenr < 2) {
            try read_line(&state);

            const vec = try parseVertices(state.current_line);
            switch (state.linenr) {
                1 => try testing.expectEqual(Vec3f.init(.{ -0.000581696, -0.734665, -0.623267 }), vec),
                2 => try testing.expectEqual(Vec3f.init(.{ 0.000283538, -1, 0.286843 }), vec),
                else => unreachable,
            }
        }
    }
}

test "parseFaces" {
    const testing = @import("std").testing;
    {
        const number_str = "13/123/33  10/11/32  1/23/23";
        const result = try parseFaces(number_str);

        try testing.expectEqual(@as(u64, 13), result.verts[0]);
        try testing.expectEqual(@as(u64, 10), result.verts[1]);
        try testing.expectEqual(@as(u64, 1), result.verts[2]);

        try testing.expectEqual(@as(u64, 123), result.tex[0]);
        try testing.expectEqual(@as(u64, 11), result.tex[1]);
        try testing.expectEqual(@as(u64, 23), result.tex[2]);

        try testing.expectEqual(@as(u64, 33), result.nrm[0]);
        try testing.expectEqual(@as(u64, 32), result.nrm[1]);
        try testing.expectEqual(@as(u64, 23), result.nrm[2]);
    }

    {
        const number_str = "13//33 10//32 1//23";
        const result = try parseFaces(number_str);

        try testing.expectEqual(@as(u64, 13), result.verts[0]);
        try testing.expectEqual(@as(u64, 10), result.verts[1]);
        try testing.expectEqual(@as(u64, 1), result.verts[2]);

        try testing.expectEqual(@as(u64, 0), result.tex[0]);
        try testing.expectEqual(@as(u64, 0), result.tex[1]);
        try testing.expectEqual(@as(u64, 0), result.tex[2]);

        try testing.expectEqual(@as(u64, 33), result.nrm[0]);
        try testing.expectEqual(@as(u64, 32), result.nrm[1]);
        try testing.expectEqual(@as(u64, 23), result.nrm[2]);
    }

    {
        const number_str = "1 2";
        const result = try parseFaces(number_str);

        try testing.expectEqual(@as(u64, 1), result.verts[0]);
        try testing.expectEqual(@as(u64, 2), result.verts[1]);
        try testing.expectEqual(@as(u64, 0), result.verts[2]);

        try testing.expectEqual(@as(u64, 0), result.tex[0]);
        try testing.expectEqual(@as(u64, 0), result.tex[1]);
        try testing.expectEqual(@as(u64, 0), result.tex[2]);

        try testing.expectEqual(@as(u64, 0), result.nrm[0]);
        try testing.expectEqual(@as(u64, 0), result.nrm[1]);
        try testing.expectEqual(@as(u64, 0), result.nrm[2]);
    }
}

test "Test Model init" {
    const testing = @import("std").testing;

    var model = Model.init(testing.allocator);
    defer model.deinit();

    try testing.expectEqual(@as(usize, 0), model.verts.capacity);

    const objFile = asAbsolutePath("./test_assets/floor.obj", testing.allocator);
    try testing.expect(objFile.len > 0);

    defer testing.allocator.free(objFile);
    try model.read(objFile);

    {
        try testing.expectEqual(@as(usize, 4), model.verts.items.len);
        try testing.expectEqual(Vec3f.init(.{ -1, -1, -1 }), model.verts.items[0]);
        try testing.expectEqual(Vec3f.init(.{ 1, -1, -1 }), model.verts.items[1]);
        try testing.expectEqual(Vec3f.init(.{ 1, -1, 1 }), model.verts.items[2]);
        try testing.expectEqual(Vec3f.init(.{ -1, -1, 1 }), model.verts.items[3]);
    }

    {
        try testing.expectEqual(@as(usize, 2), model.face_verts.items.len);
        try testing.expectEqual(@as(u64, 3), model.face_verts.items[0][0]);
        try testing.expectEqual(@as(u64, 2), model.face_verts.items[0][1]);
        try testing.expectEqual(@as(u64, 1), model.face_verts.items[0][2]);

        try testing.expectEqual(@as(u64, 4), model.face_verts.items[1][0]);
        try testing.expectEqual(@as(u64, 3), model.face_verts.items[1][1]);
        try testing.expectEqual(@as(u64, 1), model.face_verts.items[1][2]);

        try testing.expectEqual(@as(usize, 2), model.face_tex.items.len);
        try testing.expectEqual(@as(u64, 3), model.face_tex.items[0][0]);
        try testing.expectEqual(@as(u64, 2), model.face_tex.items[0][1]);
        try testing.expectEqual(@as(u64, 1), model.face_tex.items[0][2]);

        try testing.expectEqual(@as(u64, 4), model.face_tex.items[1][0]);
        try testing.expectEqual(@as(u64, 3), model.face_tex.items[1][1]);
        try testing.expectEqual(@as(u64, 1), model.face_tex.items[1][2]);

        try testing.expectEqual(@as(usize, 2), model.face_nrm.items.len);
        try testing.expectEqual(@as(u64, 1), model.face_nrm.items[0][0]);
        try testing.expectEqual(@as(u64, 1), model.face_nrm.items[0][1]);
        try testing.expectEqual(@as(u64, 1), model.face_nrm.items[0][2]);

        try testing.expectEqual(@as(u64, 1), model.face_nrm.items[1][0]);
        try testing.expectEqual(@as(u64, 1), model.face_nrm.items[1][1]);
        try testing.expectEqual(@as(u64, 1), model.face_nrm.items[1][2]);
    }
}
