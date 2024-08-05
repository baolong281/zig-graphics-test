const std = @import("std");
const gl = @import("gl");
const glfw = @import("glfw");
const sqrt = std.math.sqrt;
const shaders = @import("shaders.zig");
const bmp = @import("bmp.zig");
const za = @import("zalgebra");
var random = std.rand.DefaultPrng.init(142857);

const Vec3 = za.Vec3;
const Mat4 = za.Mat4;

const glfw_log = std.log.scoped(.glfw);
const gl_log = std.log.scoped(.gl);

var gl_procs: gl.ProcTable = undefined;

fn logGLFWError(error_code: c_int, description: [*:0]const u8) callconv(.C) void {
    glfw_log.err("{}: {s}\n", .{ error_code, description });
}

const WIDTH = 800;
const HEIGHT = 800;

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

fn createBuffers(vertices: []const f32, element_size: c_int) BufferHandles {
    var VAO: c_uint = undefined;
    gl.GenVertexArrays(1, (&VAO)[0..1]);
    gl.BindVertexArray(VAO);

    var VBO: c_uint = undefined;
    gl.GenBuffers(1, (&VBO)[0..1]);
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO);
    gl.BufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(f32) * vertices.len), &vertices[0], gl.STATIC_DRAW);

    gl.EnableVertexAttribArray(0);
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO);
    gl.VertexAttribPointer(0, element_size, gl.FLOAT, gl.FALSE, element_size * @sizeOf(f32), 0);

    return BufferHandles{ .vao = VAO, .vbo = VBO };
}

pub fn main() !void {
    const window = try initGLFW();
    defer destroyGLFW(window);

    try initGL();
    defer gl.makeProcTableCurrent(null);

    initViewport();

    const shader_program = try shaders.init_shaders();

    const cube_vertices = [_]f32{
        -1.0, -1.0, -1.0, // triangle 1 : begin
        -1.0, -1.0, 1.0,
        -1.0, 1.0, 1.0, // triangle 1 : end
        1.0,  1.0,  -1.0, // triangle 2 : begin
        -1.0, -1.0, -1.0,
        -1.0, 1.0,  -1.0, // triangle 2 : end
        1.0,  -1.0, 1.0,
        -1.0, -1.0, -1.0,
        1.0,  -1.0, -1.0,
        1.0,  1.0,  -1.0,
        1.0,  -1.0, -1.0,
        -1.0, -1.0, -1.0,
        -1.0, -1.0, -1.0,
        -1.0, 1.0,  1.0,
        -1.0, 1.0,  -1.0,
        1.0,  -1.0, 1.0,
        -1.0, -1.0, 1.0,
        -1.0, -1.0, -1.0,
        -1.0, 1.0,  1.0,
        -1.0, -1.0, 1.0,
        1.0,  -1.0, 1.0,
        1.0,  1.0,  1.0,
        1.0,  -1.0, -1.0,
        1.0,  1.0,  -1.0,
        1.0,  -1.0, -1.0,
        1.0,  1.0,  1.0,
        1.0,  -1.0, 1.0,
        1.0,  1.0,  1.0,
        1.0,  1.0,  -1.0,
        -1.0, 1.0,  -1.0,
        1.0,  1.0,  1.0,
        -1.0, 1.0,  -1.0,
        -1.0, 1.0,  1.0,
        1.0,  1.0,  1.0,
        -1.0, 1.0,  1.0,
        1.0,  -1.0, 1.0,
    };

    const triangle_vertices = [_]f32{
        -1.0, -1.0, 2.0, // triangle 1 : begin
        1.0,  -1.0, 2.0,
        0.0, 1.0, 1.5, // triangle 1 : end
    };

    var uv_buffer_data = [_]f32{ 0.000059, 1.0 - 0.000004, 0.000103, 1.0 - 0.336048, 0.335973, 1.0 - 0.335903, 1.000023, 1.0 - 0.000013, 0.667979, 1.0 - 0.335851, 0.999958, 1.0 - 0.336064, 0.667979, 1.0 - 0.335851, 0.336024, 1.0 - 0.671877, 0.667969, 1.0 - 0.671889, 1.000023, 1.0 - 0.000013, 0.668104, 1.0 - 0.000013, 0.667979, 1.0 - 0.335851, 0.000059, 1.0 - 0.000004, 0.335973, 1.0 - 0.335903, 0.336098, 1.0 - 0.000071, 0.667979, 1.0 - 0.335851, 0.335973, 1.0 - 0.335903, 0.336024, 1.0 - 0.671877, 1.000004, 1.0 - 0.671847, 0.999958, 1.0 - 0.336064, 0.667979, 1.0 - 0.335851, 0.668104, 1.0 - 0.000013, 0.335973, 1.0 - 0.335903, 0.667979, 1.0 - 0.335851, 0.335973, 1.0 - 0.335903, 0.668104, 1.0 - 0.000013, 0.336098, 1.0 - 0.000071, 0.000103, 1.0 - 0.336048, 0.000004, 1.0 - 0.671870, 0.336024, 1.0 - 0.671877, 0.000103, 1.0 - 0.336048, 0.336024, 1.0 - 0.671877, 0.335973, 1.0 - 0.335903, 0.667969, 1.0 - 0.671889, 1.000004, 1.0 - 0.671847, 0.667979, 1.0 - 0.335851 };

    const cube_handles = createBuffers(&cube_vertices, 3);
    defer deleteBuffers(cube_handles);

    // same thing but for the uv buffer
    var uv_buffer: c_uint = undefined;
    gl.GenBuffers(1, (&uv_buffer)[0..1]);
    gl.BindBuffer(gl.ARRAY_BUFFER, uv_buffer);
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * uv_buffer_data.len, &uv_buffer_data, gl.STATIC_DRAW);
    defer gl.DeleteBuffers(1, (&uv_buffer)[0..1]);

    // enable the uv attribute
    gl.EnableVertexAttribArray(1);
    gl.BindBuffer(gl.ARRAY_BUFFER, uv_buffer);
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 2 * @sizeOf(f32), 0);
    defer gl.DisableVertexAttribArray(1);

    const triangle_handles = createBuffers(&triangle_vertices, 3);
    defer deleteBuffers(triangle_handles);

    // create transformation matrices
    const projection = za.perspective(45.0, 1, 0.1, 100.0);
    const view = za.lookAt(Vec3.new(5.0, 3.0, 5.0), Vec3.zero(), Vec3.up());
    const model = Mat4.fromTranslate(Vec3.new(0.2, 0.5, 0.0));

    const mvp = Mat4.mul(projection, view.mul(model));
    mvp.debugPrint();

    const mat_id = gl.GetUniformLocation(shader_program, "MVP");

    // texture stuff
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const texture_id = try bmp.loadBMP("test/nums.bmp", allocator);
    const texture_id1 = gl.GetUniformLocation(shader_program, "texture1");

    while (!glfw.windowShouldClose(window)) {
        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
        }

        // clear the color buffer
        gl.ClearColor(0.1333, 0.19215, 0.29019, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        gl.UniformMatrix4fv(mat_id, 1, gl.FALSE, &mvp.data[0][0]);

        // use the shader program
        gl.UseProgram(shader_program);

        gl.ActiveTexture(gl.TEXTURE0);
        gl.BindTexture(gl.TEXTURE_2D, texture_id);
        gl.Uniform1i(texture_id1, 0);

        // bring the cube to the current context (?) then draw
        gl.BindVertexArray(cube_handles.vao);
        gl.BindBuffer(gl.ARRAY_BUFFER, cube_handles.vbo);
        gl.DrawArrays(gl.TRIANGLES, 0, cube_vertices.len / 3);

        // then draw the triangle
        gl.BindVertexArray(triangle_handles.vao);
        gl.BindBuffer(gl.ARRAY_BUFFER, triangle_handles.vbo);
        gl.DrawArrays(gl.TRIANGLES, 0, triangle_vertices.len / 3);

        glfw.swapBuffers(window);

        glfw.pollEvents();
    }
}
