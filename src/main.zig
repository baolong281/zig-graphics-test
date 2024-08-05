const std = @import("std");
const gl = @import("gl");
const glfw = @import("glfw");
const sqrt = std.math.sqrt;
const shaders = @import("shaders.zig");
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

pub fn main() !void {

    // -- initializing glfw window --
    _ = glfw.setErrorCallback(logGLFWError);

    var major: i32 = 0;
    var minor: i32 = 0;
    var rev: i32 = 0;

    glfw.getVersion(&major, &minor, &rev);
    std.debug.print("GLFW {}.{}.{}\n", .{ major, minor, rev });

    try glfw.init();
    defer glfw.terminate();

    glfw.windowHint(glfw.ContextVersionMajor, 3);
    glfw.windowHint(glfw.ContextVersionMinor, 3);
    glfw.windowHint(glfw.OpenGLProfile, glfw.OpenGLCoreProfile);

    std.debug.print("GLFW Init Succeeded.\n", .{});

    const window: *glfw.Window = try glfw.createWindow(WIDTH, HEIGHT, "Hello World", null, null);
    defer glfw.destroyWindow(window);

    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    // -- binding opengl context --
    if (!gl_procs.init(glfw.getProcAddress)) {
        std.debug.print("Failed to initialize gl procs\n", .{});
        return error.FailedToInitializeGlProcs;
    }

    gl.makeProcTableCurrent(&gl_procs);
    defer gl.makeProcTableCurrent(null);

    // -- setting up viewport --
    gl.Viewport(0, 0, WIDTH, HEIGHT);

    // VAO must be bound before binding the VBO
    // the purpose of VAO is to store the state of the vertex attributes
    var VAO: c_uint = undefined;
    gl.GenVertexArrays(1, (&VAO)[0..1]);
    gl.BindVertexArray(VAO);
    defer gl.DeleteVertexArrays(1, (&VAO)[0..1]);

    // enable depth test for z-buffer
    gl.Enable(gl.DEPTH_TEST);

    const shader_program = try shaders.init_shaders();

    // define the triangles vertices
    const vertices = [_]f32{
      -1.0,-1.0,-1.0, // triangle 1 : begin
    -1.0,-1.0, 1.0,
    -1.0, 1.0, 1.0, // triangle 1 : end
    1.0, 1.0,-1.0, // triangle 2 : begin
    -1.0,-1.0,-1.0,
    -1.0, 1.0,-1.0, // triangle 2 : end
    1.0,-1.0, 1.0,
    -1.0,-1.0,-1.0,
    1.0,-1.0,-1.0,
    1.0, 1.0,-1.0,
    1.0,-1.0,-1.0,
    -1.0,-1.0,-1.0,
    -1.0,-1.0,-1.0,
    -1.0, 1.0, 1.0,
    -1.0, 1.0,-1.0,
    1.0,-1.0, 1.0,
    -1.0,-1.0, 1.0,
    -1.0,-1.0,-1.0,
    -1.0, 1.0, 1.0,
    -1.0,-1.0, 1.0,
    1.0,-1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0,-1.0,-1.0,
    1.0, 1.0,-1.0,
    1.0,-1.0,-1.0,
    1.0, 1.0, 1.0,
    1.0,-1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0,-1.0,
    -1.0, 1.0,-1.0,
    1.0, 1.0, 1.0,
    -1.0, 1.0,-1.0,
    -1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    -1.0, 1.0, 1.0,
    1.0,-1.0, 1.0
    };

    const triangle_vertices = [_]f32 {
        -1.0,-1.0, 2.0, // triangle 1 : begin
        1.0,-1.0, 2.0,
        0.0, 1.0, 1.0, // triangle 1 : end
    };

    var color_buffer_data: [12*3*3]f32 = undefined;

    for(0..12*3) |i| {
        color_buffer_data[3 * i] = random.random().float(f32);
        color_buffer_data[3 * i+1] = random.random().float(f32);
        color_buffer_data[3 * i+2] = random.random().float(f32);
    }

    // -- allocate and bind vertex buffer in gpu memory --
    var vertex_buffer: c_uint = undefined;
    gl.GenBuffers(1, (&vertex_buffer)[0..1]);
    gl.BindBuffer(gl.ARRAY_BUFFER, vertex_buffer);
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, gl.STATIC_DRAW);
    defer gl.DeleteBuffers(1, (&vertex_buffer)[0..1]);

    // same thing but for the color buffer
    var color_buffer: c_uint = undefined;
    gl.GenBuffers(1, (&color_buffer)[0..1]);
    gl.BindBuffer(gl.ARRAY_BUFFER, color_buffer);
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * color_buffer_data.len, &color_buffer_data, gl.STATIC_DRAW);
    defer gl.DeleteBuffers(1, (&color_buffer)[0..1]);

    // after allocating the buffer, we need to enable the vertex attribute
    gl.EnableVertexAttribArray(0);
    gl.BindBuffer(gl.ARRAY_BUFFER, vertex_buffer);
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), 0);
    defer gl.DisableVertexAttribArray(0);

    // then we need to enable the color attribute
    gl.EnableVertexAttribArray(1);
    gl.BindBuffer(gl.ARRAY_BUFFER, color_buffer);
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), 0);
    defer gl.DisableVertexAttribArray(1);

    // we need to allocate a new vao and vbo for the triangle
    var triangle_vao: c_uint = undefined;
    gl.GenVertexArrays(1, (&triangle_vao)[0..1]);
    gl.BindVertexArray(triangle_vao);
    defer gl.DeleteVertexArrays(1, (&triangle_vao)[0..1]);

    var triangle_vbo: c_uint = undefined;
    gl.GenBuffers(1, (&triangle_vbo)[0..1]);
    gl.BindBuffer(gl.ARRAY_BUFFER, triangle_vbo);
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * triangle_vertices.len, &triangle_vertices, gl.STATIC_DRAW);
    defer gl.DeleteBuffers(1, (&triangle_vbo)[0..1]);

    gl.EnableVertexAttribArray(0);
    gl.BindBuffer(gl.ARRAY_BUFFER, triangle_vbo);
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), 0);
    defer gl.DisableVertexAttribArray(0);
    // -------------------------------------------

    // create transformation matrices
    const projection = za.perspective(45.0, 1, 0.1, 100.0);
    const view = za.lookAt(Vec3.new(5.0, 3.0, 5.0), Vec3.zero(), Vec3.up());
    const model = Mat4.fromTranslate(Vec3.new(0.2, 0.5, 0.0));

    const mvp = Mat4.mul(projection, view.mul(model));
    mvp.debugPrint();

    const mat_id = gl.GetUniformLocation(shader_program, "MVP");

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

        // bring the cube to the current context (?) then draw
        gl.BindVertexArray(VAO);
        gl.BindBuffer(gl.ARRAY_BUFFER, vertex_buffer);
        gl.DrawArrays(gl.TRIANGLES, 0, vertices.len / 3);

        // then draw the triangle
        gl.BindVertexArray(triangle_vao);
        gl.BindBuffer(gl.ARRAY_BUFFER, triangle_vbo);
        gl.DrawArrays(gl.TRIANGLES, 0, triangle_vertices.len / 3);

        glfw.swapBuffers(window);

        glfw.pollEvents();
    }
}
