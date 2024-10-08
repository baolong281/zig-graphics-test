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

// load object files into the arrays
// only supports v, vt, vn, and f
// very bad
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

    // obj file can have normals and uvs disabled
    var normals_enabled = false;
    var uv_enabled = false;

    var line_header: [128]u8 = undefined;
    // keep reading lines until EOF, max line size is 128 bytes for now
    while (try in_stream.readUntilDelimiterOrEof(&line_header, '\n')) |line| {
        // split the line into tokens
        var it = std.mem.tokenizeAny(u8, line, " ");

        // read the first value / header
        const header = it.next();

        if (header == null) {
            continue;
        }

        switch (parseLineType(header.?)) {
            .vertex => {
                const vertex = try readValuesIntoVec(&it);
                try temp_vertices.append(vertex);
            },
            .normal => {
                normals_enabled = true;
                const normal = try readValuesIntoVec(&it);
                try temp_normals.append(normal);
            },
            .uv => {
                uv_enabled = true;
                const uv = Vec2.new(
                    parseFloatTrimmed(it.next().?) catch unreachable,
                    parseFloatTrimmed(it.next().?) catch unreachable,
                );
                try temp_uvs.append(uv);
            },
            .face => {
                // for each face, read 3 vertices
                for (0..3) |_| {
                    const face = it.next().?;
                    var face_it = std.mem.tokenizeAny(u8, face, "/");
                    const vertex_index = parseIntTrimmed(face_it.next().?) catch unreachable;
                    try vertex_indices.append(vertex_index);
                    // if uvs and normals are enabled, read them
                    // uv's come first before normals
                    if (uv_enabled) {
                        const uv_index_str = face_it.next().?;
                        const uv_index = parseIntTrimmed(uv_index_str) catch unreachable;
                        try uv_indices.append(uv_index);
                    }
                    if (normals_enabled) {
                        const normal_index_str = face_it.next().?;
                        const normal_index = parseIntTrimmed(normal_index_str) catch unreachable;
                        try normal_indices.append(normal_index);
                    }
                }
            },
            else => {
                std.debug.print("Unrecognized obj header, skipping line\n", .{});
            },
        }
    }

    // for each face, push the vertices, uvs, and normals into the output arrays in the correct orderkj
    for (0..vertex_indices.items.len) |i| {
        const vertex_index = vertex_indices.items[i];
        // indices start from 1
        const vertex: Vec3 = temp_vertices.items[vertex_index - 1];
        try out_vertices.append(vertex);

        if (uv_enabled and i < uv_indices.items.len) {
            const uv_index = uv_indices.items[i];
            const uv: Vec2 = temp_uvs.items[uv_index - 1];
            // Flip the V coordinate
            // idk why
            const new_vec = Vec2.new(uv.x(), 1.0 - uv.y());
            try out_uvs.append(new_vec);
        }

        if (normals_enabled and i < normal_indices.items.len) {
            const normal_index = normal_indices.items[i];
            const normal: Vec3 = temp_normals.items[normal_index - 1];
            try out_normals.append(normal);
        }
    }
}

fn readValuesIntoVec(it: *std.mem.TokenIterator(u8, std.mem.DelimiterType.any)) !Vec3 {
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

// check if the header is a valid obj header
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
