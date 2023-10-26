const std = @import("std");
const tga = @import("stga");
const renderer = @import("renderer.zig");
const Point = @import("types.zig").Point;
const Size = @import("types.zig").Size;

const WHITE: [4]u8 = .{ 255, 255, 255, 255 };
const RED: [4]u8 = .{ 255, 0, 0, 255 };

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const size: Size = .{ .width = 100, .height = 100 };
    const start_pos: Point = .{ .x = 0, .y = @as(i64, @intCast(size.height / 2)) };
    const end_pos: Point = .{ .x = @as(i64, @intCast(size.width - 1)), .y = @as(i64, @intCast(size.height / 2)) };

    {
        const image = try tga.Image.init(allocator, size.width, size.height);
        defer image.deinit();

        renderer.draw_line(&image, start_pos, end_pos, &RED);

        try image.writeFilepath("/Users/furkanzmc/Development/tiny_renderer.zig/line_1.tga", false);
    }

    {
        const image = try tga.Image.init(allocator, size.width, size.height);
        defer image.deinit();

        renderer.draw_line_2nd(&image, start_pos, end_pos, &RED);

        try image.writeFilepath("/Users/furkanzmc/Development/tiny_renderer.zig/line_2.tga", false);
    }

    {
        const image = try tga.Image.init(allocator, size.width, size.height);
        defer image.deinit();

        renderer.draw_line_3rd(&image, start_pos, end_pos, &RED);

        try image.writeFilepath("/Users/furkanzmc/Development/tiny_renderer.zig/line_3.tga", false);
    }

    std.log.info("Finished rendering.", .{});
}
