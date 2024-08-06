const std = @import("std");
const gl = @import("gl");
const glfw = @import("glfw");
const sqrt = std.math.sqrt;
const shaders = @import("shaders.zig");
const bmp = @import("bmp.zig");
const za = @import("zalgebra");
const camera = @import("camera.zig");
const obj = @import("obj.zig");
var random = std.rand.DefaultPrng.init(142857);

const Vec2 = za.Vec2;
const Vec3 = za.Vec3;
const Mat4 = za.Mat4;

const glfw_log = std.log.scoped(.glfw);
const gl_log = std.log.scoped(.gl);

var gl_procs: gl.ProcTable = undefined;

fn logGLFWError(error_code: c_int, description: [*:0]const u8) callconv(.C) void {
    glfw_log.err("{}: {s}\n", .{ error_code, description });
}

pub const WIDTH = 800;
pub const HEIGHT = 800;

fn initGLFW() !*c_long {
    // -- initializing glfw window --
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

    const window: *glfw.Window = try glfw.createWindow(WIDTH, HEIGHT, "Hello World", null, null);
    glfw.makeContextCurrent(window);

    glfw.setInputMode(window, glfw.Cursor, glfw.CursorDisabled);

    std.debug.print("GLFW Init Succeeded.\n", .{});

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

    const element_size_int: c_int = @intCast(element_size);

    var buffer: []f32 = try allocator.alloc(f32, vertices.items.len * element_size);
    defer allocator.free(buffer);
    for (vertices.items, 0..) |vec, i| {
        buffer[i * element_size] = vec.x();
        buffer[i * element_size + 1] = vec.y();

        if (T == Vec3) {
            buffer[i * element_size + 2] = vec.z();
        }
    }

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

    gl.EnableVertexAttribArray(index);
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO);
    gl.VertexAttribPointer(index, element_size_int, gl.FLOAT, gl.FALSE, 0, 0);

    return BufferHandles{ .vao = VAO, .vbo = VBO };
}

pub fn main() !void {
    const window = try initGLFW();
    defer destroyGLFW(window);

    try initGL();
    defer gl.makeProcTableCurrent(null);
    initViewport();

    const shader_program = try shaders.init_shaders();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var cube_vertices = std.ArrayList(Vec3).init(allocator);
    var uv_buffer_data = std.ArrayList(Vec2).init(allocator);
    var normals = std.ArrayList(Vec3).init(allocator);
    defer cube_vertices.deinit();
    defer uv_buffer_data.deinit();
    defer normals.deinit();

    obj.loadObj("./test/cube.obj", &cube_vertices, &uv_buffer_data, &normals, allocator) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return err;
    };

    const cube_handles = try createBuffers(allocator, Vec3, &cube_vertices, 0);
    defer deleteBuffers(cube_handles);

    const uv_handles = try createBuffers(allocator, Vec2, &uv_buffer_data, 1);
    defer deleteBuffers(uv_handles);

    const mat_id = gl.GetUniformLocation(shader_program, "MVP");

    const texture_id = try bmp.loadBMP("test/nums.bmp", allocator);
    const texture_id1 = gl.GetUniformLocation(shader_program, "texture1");

    var controls = camera.Controls.new(window);

    while (!glfw.windowShouldClose(window)) {
        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
        }

        // clear the color buffer
        gl.ClearColor(0.1333, 0.19215, 0.29019, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        controls.updateMatricesFromInput();
        const mvp = controls.getProjectionMatrix().mul(controls.getViewMatrix());

        gl.UniformMatrix4fv(mat_id, 1, gl.FALSE, &mvp.data[0][0]);

        // use the shader program
        gl.UseProgram(shader_program);

        gl.ActiveTexture(gl.TEXTURE0);
        gl.BindTexture(gl.TEXTURE_2D, texture_id);
        gl.Uniform1i(texture_id1, 0);

        // bring the cube to the current context (?) then draw
        gl.BindVertexArray(cube_handles.vao);
        gl.BindBuffer(gl.ARRAY_BUFFER, cube_handles.vbo);

        const num_triangles: c_int = @intCast(cube_vertices.items.len);
        gl.DrawArrays(gl.TRIANGLES, 0, num_triangles);

        glfw.swapBuffers(window);

        glfw.pollEvents();
    }
}
