const std = @import("std");
const fs = std.fs;
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const gl = @import("gl");
const eql = std.mem.eql;
const mem = std.mem;

// load bmp or dds files into the texture buffer
pub fn loadTexture(file_path: []const u8, allocator: std.mem.Allocator) !c_uint {
    // get the file extension
    var it = std.mem.tokenizeAny(u8, file_path, ".");

    _ = it.next();

    const end = it.next().?;

    if (eql(u8, end, "bmp")) {
        return loadBMP(file_path, allocator);
    } else if (eql(u8, end, "dds") or eql(u8, end, "DDS")) {
        return loadDDS(file_path, allocator);
    } else {
        return error.UnsupportedFormat;
    }
}

fn loadBMP(file_path: []const u8, allocator: Allocator) !c_uint {
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

    // read values from the header
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
    // allocate then read the image data starting from the position specified in the header
    const pixels = try allocator.alloc(u8, image_size);
    defer allocator.free(pixels);
    file.seekTo(data_pos) catch return error.SeekError;
    bytes_read = try file.readAll(pixels);
    if (bytes_read != image_size) {
        std.log.err("Invalid BMP file", .{});
        return error.InvalidFileFormat;
    }

    // send and bind the buffer to opengl
    var texture_id: c_uint = undefined;
    gl.GenTextures(1, (&texture_id)[0..1]);
    gl.BindTexture(gl.TEXTURE_2D, texture_id);
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, @intCast(width), @intCast(height), 0, gl.RGBA, gl.UNSIGNED_BYTE, &pixels[0]);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.GenerateMipmap(gl.TEXTURE_2D);
    std.debug.print("bmp loaded hopefully\nwidth: {}\nheight: {}\nimage_size: {}\ndata_pos: {}\n", .{ width, height, image_size, data_pos });
    return texture_id;
}

const FOURCC_DXT1: u32 = 0x31545844; // Equivalent to "DXT1" in ASCII
const FOURCC_DXT3: u32 = 0x33545844; // Equivalent to "DXT3" in ASCII
const FOURCC_DXT5: u32 = 0x35545844; // Equivalent to "DXT5" in ASCII

fn loadDDS(file_path: []const u8, allocator: Allocator) !c_uint {
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

    // values taken from
    // https://api.dart.dev/stable/1.24.3/dart-web_gl/CompressedTextureS3TC/COMPRESSED_RGBA_S3TC_DXT1_EXT-constant.html
    const format: u32 = switch (four_cc) {
        FOURCC_DXT1 => 0x83F1, //
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
