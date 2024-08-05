const std = @import("std");
const gl = @import("gl");

const vertex_shader_source =
    \\#version 330 core
    \\layout (location = 0) in vec3 vertex_position;
    \\ layout (location = 1) in vec2 vertexUV;
    \\ out vec2 UV;
    \\uniform mat4 MVP;
    \\void main()
    \\{
    \\    gl_Position = MVP * vec4(vertex_position, 1.0);
    \\    UV = vertexUV;
    \\}
;

const fragment_shader_source =
    \\#version 330 core
    \\in vec2 UV;
    \\out vec3 color;
    \\uniform sampler2D texture1;
    \\void main()
    \\{
    \\    color = texture(texture1, UV).rgb;
    \\}
;

const ShaderError = error{
    VertexShaderFailedToCompile,
    FragmentShaderFailedToCompile,
};

pub fn init_shaders() !c_uint {
    var info_log: [1024:0]u8 = undefined;

    // -- create and compile shaders --
    const vertex_shader = gl.CreateShader(gl.VERTEX_SHADER);
    gl.ShaderSource(vertex_shader, 1, (&vertex_shader_source.ptr)[0..1], null);
    gl.CompileShader(vertex_shader);
    defer gl.DeleteShader(vertex_shader);

    var status: c_int = undefined;
    gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &status);
    if (status == gl.FALSE) {
        gl.GetShaderInfoLog(vertex_shader, info_log.len, null, &info_log);
        std.debug.print("Vertex shader compile log:\n{s}\n", .{info_log});
        return error.VertexShaderFailedToCompile;
    }

    const fragment_shader = gl.CreateShader(gl.FRAGMENT_SHADER);
    gl.ShaderSource(fragment_shader, 1, (&fragment_shader_source.ptr)[0..1], null);
    gl.CompileShader(fragment_shader);

    status = undefined;
    gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &status);
    if (status == gl.FALSE) {
        gl.GetShaderInfoLog(fragment_shader, info_log.len, null, &info_log);
        std.debug.print("Fragment shader compile log:\n{s}\n", .{info_log});
        return error.FragmentShaderFailedToCompile;
    }
    defer gl.DeleteShader(fragment_shader);

    // -- create and link shader program --
    const shader_program = gl.CreateProgram();
    gl.AttachShader(shader_program, vertex_shader);
    gl.AttachShader(shader_program, fragment_shader);
    defer gl.DetachShader(shader_program, vertex_shader);
    defer gl.DetachShader(shader_program, fragment_shader);

    gl.LinkProgram(shader_program);

    return shader_program;
}
