// const std = @import("std");
// const fs = std.fs;
// const builtin = @import("builtin");
// const Allocator = std.mem.Allocator;
// const gl = @import("gl");
// const eql = std.mem.eql;

// pub fn loadBMP(file_path: []const u8, allocator: Allocator) !c_uint {
//     var header: [54]u8 = undefined;
//     var data_pos: usize = 0;
//     var image_size: usize = 0;
//     var width: usize = 0;
//     var height: usize = 0;
//     const file = try fs.cwd().openFile(file_path, .{});
//     defer file.close();

//     const bytes_read = try file.readAll(&header);
//     if (bytes_read != 54) {
//         std.log.err("Invalid BMP header", .{});
//         return error.InvalidFileFormat;
//     }

//     if (header[0] != 'B' or header[1] != 'M') {
//         std.log.err("Invalid BMP header", .{});
//         return error.InvalidFileFormat;
//     }

//     data_pos = std.mem.readInt(u32, header[10..14], builtin.cpu.arch.endian());
//     image_size = std.mem.readInt(u32, header[34..38], builtin.cpu.arch.endian());
//     width = std.mem.readInt(u32, header[18..22], builtin.cpu.arch.endian());
//     height = std.mem.readInt(u32, header[22..26], builtin.cpu.arch.endian());

//     const bits_per_pixel = std.mem.readInt(u16, header[28..30], builtin.cpu.arch.endian());
//     if (bits_per_pixel != 24) {
//         std.log.err("Only 24-bit BMPs are supported", .{});
//         return error.UnsupportedFormat;
//     }

//     const row_size = ((bits_per_pixel * width + 31) / 32) * 4;
//     const padding = row_size - (width * 3);

//     if (image_size == 0) {
//         image_size = row_size * height;
//     }

//     if (data_pos == 0) {
//         data_pos = 54;
//     }

//     const pixels = try allocator.alloc(u8, width * height * 3);
//     defer allocator.free(pixels);

//     try file.seekTo(data_pos);

//     var y: usize = 0;
//     while (y < height) : (y += 1) {
//         const row_start = (height - 1 - y) * width * 3;
//         _ = try file.read(pixels[row_start .. row_start + width * 3]);

//         // Swap R and B channels
//         var x: usize = 0;
//         while (x < width * 3) : (x += 3) {
//             const temp = pixels[row_start + x];
//             pixels[row_start + x] = pixels[row_start + x + 2];
//             pixels[row_start + x + 2] = temp;
//         }

//         if (padding > 0) {
//             const padding_i64: i64 = @intCast(padding);
//             try file.seekBy(padding_i64);
//         }
//     }

//     var texture_id: c_uint = undefined;
//     gl.GenTextures(1, (&texture_id)[0..1]);
//     gl.BindTexture(gl.TEXTURE_2D, texture_id);
//     gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, @intCast(width), @intCast(height), 0, gl.RGB, gl.UNSIGNED_BYTE, &pixels[0]);
//     gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
//     gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
//     gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
// gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
//     gl.GenerateMipmap(gl.TEXTURE_2D);

//     std.debug.print("BMP loaded: width: {}, height: {}, image_size: {}, data_pos: {}\n", .{ width, height, image_size, data_pos });

//     return texture_id;
// }

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

const mem = std.mem;

const FOURCC_DXT1: u32 = 0x31545844; // Equivalent to "DXT1" in ASCII
const FOURCC_DXT3: u32 = 0x33545844; // Equivalent to "DXT3" in ASCII
const FOURCC_DXT5: u32 = 0x35545844; // Equivalent to "DXT5" in ASCII

pub fn loadDDS(file_path: []const u8, allocator: Allocator) !c_uint {
    const file = try fs.cwd().openFile(file_path, .{});
    defer file.close();

    var filecode: [4]u8 = undefined;
    _ = try file.readAll(&filecode);
    if (!mem.eql(u8, &filecode, "DDS ")) {
        return error.InvalidFileFormat;
    }

    var header: [124]u8 = undefined;
    _ = try file.readAll(&header);

    const height = mem.readInt(u32, header[8..12], builtin.cpu.arch.endian());
    const width = mem.readInt(u32, header[12..16], builtin.cpu.arch.endian());
    const linear_size = mem.readInt(u32, header[16..20], builtin.cpu.arch.endian());
    const mip_map_count = mem.readInt(u32, header[24..28], builtin.cpu.arch.endian());
    const four_cc = mem.readInt(u32, header[80..84], builtin.cpu.arch.endian());

    const buf_size = if (mip_map_count > 1) linear_size * 2 else linear_size;
    const buffer = try allocator.alloc(u8, buf_size);
    defer allocator.free(buffer);

    _ = try file.readAll(buffer);

    const format: u32 = switch (four_cc) {
        FOURCC_DXT1 => 0x83F1,
        FOURCC_DXT3 => 0x83F2,
        FOURCC_DXT5 => 0x83F3,
        else => return error.UnsupportedFormat,
    };

    var texture_id: c_uint = undefined;
    gl.GenTextures(1, (&texture_id)[0..1]);
    gl.BindTexture(gl.TEXTURE_2D, texture_id);
    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);

    const block_size: u32 = if (format == 0x83F1) 8 else 16;
    var offset: usize = 0;
    var current_width = width;
    var current_height = height;

    var level: u32 = 0;
    while (level < mip_map_count and (current_width > 0 or current_height > 0)) : (level += 1) {
        const size = (((current_width + 3) / 4) * ((current_height + 3) / 4)) * block_size;
        gl.CompressedTexImage2D(
            gl.TEXTURE_2D,
            @intCast(level),
            @intCast(format),
            @intCast(current_width),
            @intCast(current_height),
            0,
            @intCast(size),
            &buffer[offset],
        );

        offset += size;
        current_width /= 2;
        current_height /= 2;
        if (current_width < 1) current_width = 1;
        if (current_height < 1) current_height = 1;
    }

    std.debug.print("DDS loaded successfully\nwidth: {}\nheight: {}\nmip_map_count: {}\n", .{ width, height, mip_map_count });
    return texture_id;
}
