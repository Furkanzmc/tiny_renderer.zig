const std = @import("std");
const tga = @import("tga.zig");

const RED: [4]usize = .{ 255, 255, 255, 255 };

pub fn main() !void {
    const image = try tga.Image.init(100, 100);
    defer image.deinit();

    image.set(51, 41, RED);
    image.writeFilepath("/Users/furkanzmc/Development/tiny_renderer/zig-out/file.tag", false);
}
