const std = @import("std");
const gl = @import("gl");
const glfw = @import("glfw");

const glfw_log = std.log.scoped(.glfw);
const gl_log = std.log.scoped(.gl);

var gl_procs: gl.ProcTable = undefined;

const vertex_shader_source =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\void main()
    \\{
    \\    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
    \\}
;

const fragment_shader_source =
    \\#version 330 core
    \\out vec4 FragColor;
    \\void main()
    \\{
    \\    FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
    \\}
;

fn logGLFWError(error_code: c_int, description: [*:0]const u8) callconv(.C) void {
    glfw_log.err("{}: {s}\n", .{ error_code, description });
}

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

    const window: *glfw.Window = try glfw.createWindow(800, 640, "Hello World", null, null);
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
    gl.Viewport(0, 0, 800, 640);

    // -- create and compile shaders --
    const vertex_shader = gl.CreateShader(gl.VERTEX_SHADER);
    gl.ShaderSource(vertex_shader, 1, (&vertex_shader_source.ptr)[0..1], null);
    gl.CompileShader(vertex_shader);

    const fragment_shader = gl.CreateShader(gl.FRAGMENT_SHADER);
    gl.ShaderSource(fragment_shader, 1, (&fragment_shader_source.ptr)[0..1], null);
    gl.CompileShader(fragment_shader);

    // -- create and link shader program --
    const shader_program = gl.CreateProgram();
    gl.AttachShader(shader_program, vertex_shader);
    gl.AttachShader(shader_program, fragment_shader);
    defer gl.DeleteShader(vertex_shader);
    defer gl.DeleteShader(fragment_shader);
    defer gl.DeleteProgram(shader_program);

    gl.LinkProgram(shader_program);

    // define the triangles vertices
    const vertices = [_]f32{
        -0.5, -0.5, 0.0,
        0.5,  -0.5, 0.0,
        0.0,  0.5,  0.0,
    };

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

    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    gl.BindVertexArray(0);

    while (!glfw.windowShouldClose(window)) {
        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
        }

        // clear the color buffer
        gl.ClearColor(0.2, 0.3, 0.3, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);
        // use the shader program
        gl.UseProgram(shader_program);
        // bind the vertex array
        gl.BindVertexArray(VAO);
        // draw the triangle
        gl.DrawArrays(gl.TRIANGLES, 0, 3);
        glfw.swapBuffers(window);


        glfw.pollEvents();
    }
}
