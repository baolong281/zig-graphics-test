const std = @import("std");
const fs = std.fs;
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const gl = @import("gl");
const eql = std.mem.eql;

pub fn loadBMP(file_path: []const u8, allocator: Allocator) !c_uint {
    var header: [54]u8 = undefined;
    var data_pos: usize = 0;
    var image_size: usize = 0;
    var width: usize = 0;
    var height: usize = 0;

    const file = try fs.cwd().openFile(file_path, .{});
    defer file.close();

    var bytes_read = try file.readAll(&header);

    if (bytes_read != 54) {
        std.log.err("Invalid BMP header", .{});
        return error.InvalidFileFormat;
    }

    if (header[0] != 'B' or header[1] != 'M') {
        std.log.err("Invalid BMP header", .{});
        return error.InvalidFileFormat;
    }

    data_pos = std.mem.readInt(u32, header[10..14], builtin.cpu.arch.endian());
    image_size = std.mem.readInt(u32, header[34..38], builtin.cpu.arch.endian());
    width = std.mem.readInt(u32, header[18..22], builtin.cpu.arch.endian());
    height = std.mem.readInt(u32, header[22..26], builtin.cpu.arch.endian());

    if (image_size == 0) {
        std.debug.print("BMP: image_size == 0, guessing image_size\n", .{});
        image_size = width * height * 3;
    }
    if (data_pos == 0) {
        std.debug.print("BMP: data_pos == 0, guessing data_pos\n", .{});
        data_pos = 54;
    }

    const pixels = try allocator.alloc(u8, image_size);
    defer allocator.free(pixels);

    file.seekTo(data_pos) catch return error.SeekError;
    bytes_read = try file.readAll(pixels);
    if (bytes_read != image_size) {
        std.log.err("Invalid BMP file", .{});
        return error.InvalidFileFormat;
    }

    var texture_id: c_uint = undefined;
    gl.GenTextures(1, (&texture_id)[0..1]);
    gl.BindTexture(gl.TEXTURE_2D, texture_id);

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, @intCast(width), @intCast(height), 0, gl.RGBA, gl.UNSIGNED_BYTE, &pixels[0]);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.GenerateMipmap(gl.TEXTURE_2D);

    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);

    std.debug.print("bmp loaded hopefully\nwidth: {}\nheight: {}\nimage_size: {}\ndata_pos: {}\n", .{ width, height, image_size, data_pos });

    return texture_id;
}
