const std = @import("std");
const gl = @import("gl");
const glfw = @import("glfw");
const shaders = @import("shaders.zig");
const bmp = @import("bmp.zig");
const za = @import("zalgebra");
const camera = @import("camera.zig");
const obj = @import("obj.zig");

const Vec2 = za.Vec2;
const Vec3 = za.Vec3;
const Mat4 = za.Mat4;

const glfw_log = std.log.scoped(.glfw);
const gl_log = std.log.scoped(.gl);

var gl_procs: gl.ProcTable = undefined;

fn logGLFWError(error_code: c_int, description: [*:0]const u8) callconv(.C) void {
    glfw_log.err("{}: {s}\n", .{ error_code, description });
}

pub const WIDTH = 1000;
pub const HEIGHT = 1000;

fn initGLFW() !*c_long {
    _ = glfw.setErrorCallback(logGLFWError);

    var major: i32 = 0;
    var minor: i32 = 0;
    var rev: i32 = 0;

    glfw.getVersion(&major, &minor, &rev);
    std.debug.print("GLFW {}.{}.{}\n", .{ major, minor, rev });

    try glfw.init();

    glfw.windowHint(glfw.ContextVersionMajor, 3);
    glfw.windowHint(glfw.ContextVersionMinor, 3);
    glfw.windowHint(glfw.OpenGLProfile, glfw.OpenGLCoreProfile);

    std.debug.print("GLFW Init Succeeded.\n", .{});

    const window: *glfw.Window = try glfw.createWindow(WIDTH, HEIGHT, "zig-graphics-test", null, null);
    glfw.makeContextCurrent(window);

    glfw.setInputMode(window, glfw.Cursor, glfw.CursorDisabled);

    return window;
}

fn destroyGLFW(window: *glfw.Window) void {
    glfw.terminate();
    glfw.destroyWindow(window);
    glfw.makeContextCurrent(null);
}

fn initGL() !void {
    if (!gl_procs.init(glfw.getProcAddress)) {
        std.debug.print("Failed to initialize gl procs\n", .{});
        return error.FailedToInitializeGlProcs;
    }

    gl.makeProcTableCurrent(&gl_procs);
}

fn initViewport() void {
    gl.Viewport(0, 0, WIDTH, HEIGHT);
    gl.Enable(gl.DEPTH_TEST);
    gl.Enable(gl.CULL_FACE);
    // gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);
}

const BufferHandles = struct {
    vao: c_uint,
    vbo: c_uint,
};

fn deleteBuffers(handles: BufferHandles) void {
    var vao: c_uint = handles.vao;
    var vbo: c_uint = handles.vbo;
    gl.DeleteVertexArrays(1, (&vao)[0..1]);
    gl.DeleteBuffers(1, (&vbo)[0..1]);
}

// create vao and vbo's for the index
fn createBuffers(allocator: std.mem.Allocator, comptime T: type, vertices: *std.ArrayList(T), index: c_uint) !BufferHandles {
    var element_size: c_uint = undefined;

    comptime {
        if (T != Vec2 and T != Vec3) {
            @compileError("T must be a struct (Vec2 or Vec3)");
        }
    }

    if (T == Vec2) {
        element_size = 2;
    } else if (T == Vec3) {
        element_size = 3;
    }

    // if we just pass the array of vectors directly then it won't work
    var buffer: []f32 = try allocator.alloc(f32, vertices.items.len * element_size);
    defer allocator.free(buffer);

    for (vertices.items, 0..) |vec, i| {
        buffer[i * element_size] = vec.x();
        buffer[i * element_size + 1] = vec.y();

        if (T == Vec3) {
            buffer[i * element_size + 2] = vec.z();
        }
    }

    std.debug.print("vertices size {any}\n", .{vertices.items.len});
    std.debug.print("buffer length {any}\n", .{buffer.len});

    // don't create a VAO if we are creating buffers for uv's
    // idk why
    var VAO: c_uint = undefined;
    if (index == 0) {
        gl.GenVertexArrays(1, (&VAO)[0..1]);
        gl.BindVertexArray(VAO);
    }

    var VBO: c_uint = undefined;
    gl.GenBuffers(1, (&VBO)[0..1]);
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO);
    gl.BufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(f32) * buffer.len), &buffer[0], gl.STATIC_DRAW);

    return BufferHandles{ .vao = VAO, .vbo = VBO };
}

// enable the buffer at the index
fn enableBuffer(handles: BufferHandles, index: c_uint, element_size: c_int) void {
    gl.EnableVertexAttribArray(index);
    gl.BindBuffer(gl.ARRAY_BUFFER, handles.vbo);
    gl.VertexAttribPointer(index, element_size, gl.FLOAT, gl.FALSE, 0, 0);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // parse args
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next().?;
    var path: [:0]const u8 = undefined;

    if (args.next()) |arg| {
        path = arg;
    } else {
        path = "test/bunny.obj";
    }

    var texture_path: [:0]const u8 = undefined;
    var textures_enabled = false;
    if (args.next()) |arg| {
        texture_path = arg;
        textures_enabled = true;
    } else {
        texture_path = "test/uvmap.DDS";
    }

    std.debug.print("file path: {any}\n", .{path});
    std.debug.print("texture path: {any}\n", .{texture_path});

    const window = initGLFW() catch |err| {
        std.debug.print("Error intializing GLFW: {any}\n", .{err});
        return err;
    };

    defer destroyGLFW(window);

    try initGL();
    defer gl.makeProcTableCurrent(null);
    initViewport();

    const shader_program = try shaders.init_shaders();

    const texture_id = try bmp.loadTexture(texture_path, allocator);
    const texture_location = gl.GetUniformLocation(shader_program, "texture1");

    var object_vertices = std.ArrayList(Vec3).init(allocator);
    var uv_buffer_data = std.ArrayList(Vec2).init(allocator);
    var normals = std.ArrayList(Vec3).init(allocator);
    defer object_vertices.deinit();
    defer uv_buffer_data.deinit();
    defer normals.deinit();

    obj.loadObj(path, &object_vertices, &uv_buffer_data, &normals, allocator) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return err;
    };

    const cube_handles = try createBuffers(allocator, Vec3, &object_vertices, 0);
    defer deleteBuffers(cube_handles);

    var uv_handles: ?BufferHandles = null;
    if (uv_buffer_data.items.len != 0) {
        uv_handles = try createBuffers(allocator, Vec2, &uv_buffer_data, 1);
    } else {
        std.debug.print("No UVs found in obj file, ignoring\n", .{});
    }

    defer if (uv_handles) |handles| {
        deleteBuffers(handles);
    };

    var normal_handles: ?BufferHandles = null;
    if (normals.items.len != 0) {
        normal_handles = try createBuffers(allocator, Vec3, &normals, 2);
    } else {
        std.debug.print("No normals found in obj file, ignoring\n", .{});
    }

    defer if (normal_handles) |handles| {
        deleteBuffers(handles);
    };

    const matrix_id = gl.GetUniformLocation(shader_program, "MVP");
    const view_matrix_id = gl.GetUniformLocation(shader_program, "V");
    const model_matrix_id = gl.GetUniformLocation(shader_program, "M");

    const light_id = gl.GetUniformLocation(shader_program, "LightPosition_worldspace");

    var controls = camera.Controls.new(window);
    gl.ClearColor(0.75, 0.75, 0.75, 1.0);

    while (!glfw.windowShouldClose(window)) {
        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
        }

        // clear the color buffer
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // use the shader program
        gl.UseProgram(shader_program);

        // update the matrices
        controls.updateMatricesFromInput();
        const projection = controls.getProjectionMatrix();
        const view = controls.getViewMatrix();
        const model = Mat4.fromScale(Vec3.new(1, 1, 1));
        const mvp = projection.mul(view).mul(model);

        gl.UniformMatrix4fv(matrix_id, 1, gl.FALSE, &mvp.data[0][0]);
        gl.UniformMatrix4fv(view_matrix_id, 1, gl.FALSE, &view.data[0][0]);
        gl.UniformMatrix4fv(model_matrix_id, 1, gl.FALSE, &model.data[0][0]);

        const light_pos = Vec3.new(0, 3, -8);
        gl.Uniform3f(light_id, light_pos.x(), light_pos.y(), light_pos.z());

        // activate textures
        gl.ActiveTexture(gl.TEXTURE0);
        gl.BindTexture(gl.TEXTURE_2D, texture_id);
        gl.Uniform1i(texture_location, 0);

        // enabled the buffers if they exist
        enableBuffer(cube_handles, 0, 3);
        if (uv_handles != null) {
            enableBuffer(uv_handles.?, 1, 2);
        }
        if (normal_handles != null) {
            enableBuffer(normal_handles.?, 2, 3);
        }

        // draw the object
        const num_triangles: c_int = @intCast(object_vertices.items.len);
        gl.DrawArrays(gl.TRIANGLES, 0, num_triangles);

        gl.DisableVertexAttribArray(0);
        gl.DisableVertexAttribArray(1);
        gl.DisableVertexAttribArray(2);

        glfw.swapBuffers(window);
        glfw.pollEvents();
    }
}
