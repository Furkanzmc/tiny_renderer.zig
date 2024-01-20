const std = @import("std");

pub fn asAbsolutePath(comptime relativePath: []const u8, allocator: std.mem.Allocator) []u8 {
    const input_path_resolved = std.fs.realpathAlloc(allocator, relativePath) catch |e| {
        std.log.err("Could not resolve input path '{s}', {}", .{ relativePath, e });
        return "";
    };
    return input_path_resolved;
}
