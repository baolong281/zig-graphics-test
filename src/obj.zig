const std = @import("std");
const za = @import("zalgebra");
const eql = std.mem.eql;
const Vec3 = za.Vec3;
const Vec2 = za.Vec2;

const LineType = enum {
    vertex,
    normal,
    uv,
    face,
    other,
};

pub fn loadObj(
    path: []const u8,
    out_vertices: *std.ArrayList(za.Vec3),
    out_uvs: *std.ArrayList(za.Vec2),
    out_normals: *std.ArrayList(za.Vec3),
    allocator: std.mem.Allocator,
) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var vertex_indices = std.ArrayList(usize).init(allocator);
    var uv_indices = std.ArrayList(usize).init(allocator);
    var normal_indices = std.ArrayList(usize).init(allocator);
    defer vertex_indices.deinit();
    defer uv_indices.deinit();
    defer normal_indices.deinit();

    var temp_vertices = std.ArrayList(za.Vec3).init(allocator);
    var temp_uvs = std.ArrayList(za.Vec2).init(allocator);
    var temp_normals = std.ArrayList(za.Vec3).init(allocator);
    defer temp_vertices.deinit();
    defer temp_uvs.deinit();
    defer temp_normals.deinit();

    var line_header: [128]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&line_header, '\n')) |line| {
        std.debug.print("currently reading line: {s}\n", .{line});
        var it = std.mem.splitSequence(u8, line, " ");

        const header = it.next().?;
        switch (parseLineType(header)) {
            .vertex => {
                const vertex = try readValuesIntoVec(&it);
                try temp_vertices.append(vertex);
            },
            .normal => {
                const normal = try readValuesIntoVec(&it);
                try temp_normals.append(normal);
            },
            .uv => {
                const uv = Vec2.new(
                    parseFloatTrimmed(it.next().?) catch unreachable,
                    parseFloatTrimmed(it.next().?) catch unreachable,
                );
                try temp_uvs.append(uv);
            },
            .face => {
                for (0..3) |_| {
                    const face = it.next().?;
                    var face_it = std.mem.splitSequence(u8, face, "/");
                    std.debug.print("iter value: {s}\n", .{face});
                    vertex_indices.append(parseIntTrimmed(face_it.next().?) catch unreachable) catch unreachable;
                    uv_indices.append(parseIntTrimmed(face_it.next().?) catch unreachable) catch unreachable;
                    normal_indices.append(parseIntTrimmed(face_it.next().?) catch unreachable) catch unreachable;
                }
            },
            else => {
                std.debug.print("Unrecognized obj header, skipping line\n", .{});
            },
        }
    }

    // for (vertex_indices.items) |index| {
    //     std.debug.print(" vertex length {any}, index: {any}\n", .{ vertex_indices.items.len, index });
    //     const vertex: Vec3 = temp_vertices.items[index - 1];
    //     try out_vertices.append(vertex);

    //     const uv: Vec2 = temp_uvs.items[uv_indices.items[index] - 1];
    //     try out_uvs.append(uv);

    //     const normal: Vec3 = temp_normals.items[normal_indices.items[index] - 1];
    //     try out_normals.append(normal);

    //     std.debug.print("vertex_len: {any}\n", .{out_vertices.items.len});
    // }

    for (0..vertex_indices.items.len) |i| {
        const vertex_index = vertex_indices.items[i];
        const vertex: Vec3 = temp_vertices.items[vertex_index - 1];
        try out_vertices.append(vertex);

        const uv_index = uv_indices.items[i];
        const uv: Vec2 = temp_uvs.items[uv_index - 1];
        try out_uvs.append(uv);

        const normal_index = normal_indices.items[i];
        const normal: Vec3 = temp_normals.items[normal_index - 1];
        try out_normals.append(normal);
    }
}

fn readValuesIntoVec(it: *std.mem.SplitIterator(u8, std.mem.DelimiterType.sequence)) !Vec3 {
    return Vec3.new(
        parseFloatTrimmed(it.next().?) catch unreachable,
        parseFloatTrimmed(it.next().?) catch unreachable,
        parseFloatTrimmed(it.next().?) catch unreachable,
    );
}

fn parseFloatTrimmed(value: []const u8) !f32 {
    return std.fmt.parseFloat(f32, std.mem.trim(u8, value, &std.ascii.whitespace));
}

fn parseIntTrimmed(value: []const u8) !u32 {
    return std.fmt.parseInt(u32, std.mem.trim(u8, value, &std.ascii.whitespace), 10);
}

fn parseLineType(header: []const u8) LineType {
    if (eql(u8, header, "v")) {
        return .vertex;
    } else if (eql(u8, header, "vn")) {
        return .normal;
    } else if (eql(u8, header, "vt")) {
        return .uv;
    } else if (eql(u8, header, "f")) {
        return .face;
    }
    return .other;
}
