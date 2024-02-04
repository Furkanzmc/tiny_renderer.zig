const std = @import("std");
const tga = @import("stga");
const renderer = @import("renderer.zig");
const PointU = @import("types.zig").Point(u64);
const Size = @import("types.zig").Size;
const Model = @import("model.zig").Model;
const asAbsolutePath = @import("testUtils.zig").asAbsolutePath;

const WHITE: [4]u8 = .{ 255, 255, 255, 255 };
const RED: [4]u8 = .{ 255, 0, 0, 255 };

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // const size: Size = .{ .width = 100, .height = 100 };
    // const start_pos: PointU = .{ .x = 0, .y = @as(i64, @intCast(size.height / 2)) };
    // const end_pos: PointU = .{ .x = @as(i64, @intCast(size.width - 1)), .y = @as(i64, @intCast(size.height / 2)) };
    const current_dir = asAbsolutePath("./", allocator);
    if (current_dir.len == 0) {
        return;
    }

    // {
    //     const image = try tga.Image.init(allocator, size.width, size.height);
    //     defer image.deinit();

    //     renderer.draw_line(&image, start_pos, end_pos, &RED);

    //     try image.writeFilepath(try std.fmt.allocPrint(allocator, "{s}/{s}", .{ current_dir, "zig-out/line_1.tga" }), false);
    // }

    // {
    //     const image = try tga.Image.init(allocator, size.width, size.height);
    //     defer image.deinit();

    //     renderer.draw_line_2nd(&image, start_pos, end_pos, &RED);

    //     try image.writeFilepath(try std.fmt.allocPrint(allocator, "{s}/{s}", .{ current_dir, "zig-out/line_2.tga" }), false);
    // }

    // {
    //     const image = try tga.Image.init(allocator, size.width, size.height);
    //     defer image.deinit();

    //     renderer.draw_line(&image, start_pos, end_pos, &RED);

    //     try image.writeFilepath(try std.fmt.allocPrint(allocator, "{s}/{s}", .{ current_dir, "zig-out/line_3.tga" }), false);
    // }

    // {
    //     const image = try tga.Image.init(allocator, size.width, size.height);
    //     defer image.deinit();

    //     renderer.draw_line(&image, PointU{ .x = 0, .y = 0 }, PointU{ .x = size.width - 1, .y = 0 }, &RED);
    //     renderer.draw_line(&image, PointU{ .x = size.width - 1, .y = 0 }, PointU{ .x = size.width - 1, .y = size.height - 1 }, &RED);
    //     renderer.draw_line(&image, PointU{ .x = size.width - 1, .y = size.height - 1 }, PointU{ .x = 0, .y = size.height - 1 }, &RED);
    //     renderer.draw_line(&image, PointU{ .x = 0, .y = size.height - 1 }, PointU{ .x = 0, .y = 0 }, &RED);

    //     try image.writeFilepath(try std.fmt.allocPrint(allocator, "{s}/{s}", .{ current_dir, "zig-out/rectangle.tga" }), false);
    // }

    {
        const image = try tga.Image.init(allocator, 800, 800);
        defer image.deinit();

        var model = Model.init(allocator);
        defer model.deinit();

        const model_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ current_dir, "tutorial/obj/african_head.obj" });
        try model.read(model_path);

        renderer.render_model(&model, &image, WHITE);

        try image.writeFilepath(try std.fmt.allocPrint(allocator, "{s}/{s}", .{ current_dir, "zig-out/african_head.tga" }), false);
    }

    std.log.info("Finished rendering.", .{});
}
