const std = @import("std");
const gl = @import("gl");
const glfw = @import("glfw");
const sqrt = std.math.sqrt;
const shaders = @import("shaders.zig");
const za = @import("zalgebra");

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

    // define the triangles vertices
    const vertices = [_]f32{
        -1.0, -1.0, 0.0,
        1.0,  -1.0, 0.0,
        0.0,  1.0,  0.0,

        -1.0, -1.0, 1.0,
        1.0,  -1.0, 1.0,
        0.0,  1.0,  1.0,

        -1.0, -1.0, -1.0,
        1.0,  -1.0, -1.0,
        0.0,  1.0,  -1.0,
    };

    const shader_program = try shaders.init_shaders();

    // -- allocate and bind vertex buffer in gpu memory --
    // VAO must be bound before binding the VBO
    // the purpose of VAO is to store the state of the vertex attributes
    var VAO: c_uint = undefined;
    gl.GenVertexArrays(1, (&VAO)[0..1]);
    gl.BindVertexArray(VAO);
    defer gl.DeleteVertexArrays(1, (&VAO)[0..1]);

    // allocate and bind vertex buffer in gpu memory
    var VBO: c_uint = undefined;
    gl.GenBuffers(1, (&VBO)[0..1]);
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO);
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, gl.STATIC_DRAW);
    defer gl.DeleteBuffers(1, (&VBO)[0..1]);

    // this specifies the layout of the data in the VBO
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), 0);

    // enable the vertex attribute
    gl.EnableVertexAttribArray(0);

    // bind these to bring them into effect
    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    gl.BindVertexArray(0);

    // create transformation matrices
    const projection = za.perspective(45.0, 800.0 / 600.0, 0.1, 100.0);
    const view = za.lookAt(Vec3.new(3.0, 2.0, -2.0), Vec3.zero(), Vec3.up());
    const model = Mat4.fromTranslate(Vec3.new(0.2, 0.5, 0.0));

    const mvp = Mat4.mul(projection, view.mul(model));
    mvp.debugPrint();

    const mat_id = gl.GetUniformLocation(shader_program, "MVP");

    while (!glfw.windowShouldClose(window)) {
        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
        }

        // clear the color buffer
        gl.ClearColor(0.2, 0.3, 0.3, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        gl.UniformMatrix4fv(mat_id, 1, gl.FALSE, &mvp.data[0][0]);

        // use the shader program
        gl.UseProgram(shader_program);
        // bind the vertex array
        gl.BindVertexArray(VAO);
        // draw the triangle
        gl.DrawArrays(gl.TRIANGLES, 0, vertices.len / 3);
        glfw.swapBuffers(window);

        glfw.pollEvents();
    }
}
