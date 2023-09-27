const std = @import("std");

pub const Image = struct {
    allocator: std.mem.Allocator,
    pixels: []u8,
    width: usize,
    height: usize,

    pub fn init(width: usize, height: usize) !@This() {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);

        const allocator = std.mem.Allocator;
        return @This(){
            .allocator = std.mem.Allocator,
            .width = width,
            .height = height,
            .pixels = try allocator.alloc(u8, width * height * 4),
        };
    }

    pub fn deinit(self: *const @This()) void {
        if (self.pixels.len > 0) {
            self.allocator.free(self.pixels);
        }
    }
};

test "Test Initialization" {
    const img = Image.init(std.mem.Allocator, 100, 100);
    const expect = std.testing.expect;
    try expect(img.width > 0);
}

// pub fn main() !void {
//     const file = try std.fs.cwd().createFile("foo.tga", .{ .read = true });
//     defer file.close();

//     const width: u16 = 300;
//     const height: u16 = 200;

//     // https://stackoverflow.com/a/49658800/695615
//     // https://en.wikipedia.org/wiki/Truevision_TGA
//     // http://paulbourke.net/dataformats/tga/
//     // Note that all multi-byte values are little-endian.
//     const header: [18]u8 = .{
//         0, // 1  - No ID field (length of 0)
//         0, // 2  - No color map
//         2, // 3  - Uncompressed true-color image
//         0, // 4  \
//         0, // 5  |
//         0, // 6  | Color map information (none)
//         0, // 7  |
//         0, // 8  /
//         0, // 9  \ Origin X (16 bits)
//         0, // 10 /
//         0, // 11 \ Origin Y (16 bits)
//         0, // 12 /
//         width & 255, // 13 \ Width (px) mask last 8 bits
//         (width >> 8) & 255, // 14 / Width (px) right shift and mask to get first 8 bits
//         height & 255, // 15 \ Height (px) last
//         (height >> 8) & 255, // 16 / Height (px) first
//         24, // 17 - Bits per pixel (3 colors, 8 bits each)
//         0b00100000, // 18 - Image descriptor (Bits 4,5 are origin. Set to "top left".)
//     };

//     try file.writeAll(&header);

//     // Scale from image dimensions to color min and max.
//     var w_scale: f32 = 255 / @as(f32, width);
//     var h_scale: f32 = 255 / @as(f32, height);

//     // Buffer one row's worth of pixels (makes a huge difference on huge images).
//     var out_buffer: [3 * width]u8 = undefined;

//     var w: u32 = 0; // Pixel counter per row (width)
//     var h: u32 = 0; // Row counter (height)

//     // For height's worth of rows...
//     while (h < height) : (h += 1) {

//         // Reset row pixel counter
//         w = 0;

//         // Fill row buffer
//         while (w < width) : (w += 1) {
//             // IMPORTANT: TGA stores in BGR order, not RGB.
//             const pixel_r = w * 3 + 2;
//             const pixel_g = w * 3 + 1;
//             const pixel_b = w * 3;

//             out_buffer[pixel_r] = @as(u8, @intFromFloat(@as(f32, @floatFromInt(w)) * w_scale)); // increase across
//             out_buffer[pixel_g] = @as(u8, @intFromFloat(@as(f32, @floatFromInt(h)) * h_scale)); // increase down
//             out_buffer[pixel_b] = @as(u8, @intFromFloat(@as(f32, @floatFromInt(width - w)) * w_scale)); // decrease across
//         }

//         // Write row
//         try file.writeAll(&out_buffer);
//     }
// }
