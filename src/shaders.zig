const std = @import("std");
const gl = @import("gl");

const vertex_shader_source =
    \\#version 330 core
    \\layout (location = 0) in vec3 vertex_position;
    \\layout (location = 1) in vec2 vertexUV;
    \\layout (location = 2) in vec3 vertexNormal;
    \\
    \\out vec2 UV;
    \\out vec3 Position_worldspace;
    \\out vec3 Normal_cameraspace;
    \\out vec3 LightDirection_cameraspace;
    \\out vec3 EyeDirection_cameraspace;
    \\
    \\uniform mat4 MVP;
    \\uniform mat4 V;
    \\uniform mat4 M;
    \\uniform vec3 LightPosition_worldspace;
    \\void main()
    \\{
    \\    gl_Position = MVP * vec4(vertex_position, 1.0);
    \\    Position_worldspace = (M * vec4(vertex_position, 1.0)).xyz;
    \\    
    \\    // get the position of the vertex in camera space then calculate the direction from the eye to the vertex
    \\    vec3 vertexPosition_cameraspace = ( V * M * vec4(vertex_position, 1.0)).xyz;
    \\    EyeDirection_cameraspace = vec3(0,0,0) - vertexPosition_cameraspace;
    \\    
    \\    vec3 LightPosition_cameraspace = ( V * vec4(LightPosition_worldspace,1)).xyz;
    \\    LightDirection_cameraspace = LightPosition_cameraspace + EyeDirection_cameraspace;
    \\
    \\    Normal_cameraspace = (V * transpose(inverse(M)) * vec4(vertexNormal,0)).xyz; // Only correct if ModelMatrix does not scale the model ! Use its inverse transpose if not.
    \\    
    \\    UV = vertexUV;
    \\}
;

const fragment_shader_source =
    \\#version 330 core
    \\in vec2 UV;
    \\in vec3 Position_worldspace;
    \\in vec3 Normal_cameraspace;
    \\in vec3 EyeDirection_cameraspace;
    \\in vec3 LightDirection_cameraspace;
    \\
    \\out vec3 color;
    \\
    \\uniform mat4 MV;
    \\uniform vec3 LightPosition_worldspace;
    \\uniform sampler2D texture1;
    \\void main()
    \\{
    \\    vec3 LightColor = vec3(1,1,1);
    \\    float LightPower = 50.0;
    \\
    \\    vec3 MaterialDiffuseColor = texture(texture1, UV).rgb;
    \\    vec3 MaterialAmbientColor = vec3(0.1,0.1,0.1) * MaterialDiffuseColor;
    \\    vec3 MaterialSpecularColor = vec3(0.2,0.2,0.2);
    \\     
    \\    float distance = length( LightPosition_worldspace - Position_worldspace );
    \\
    \\    vec3 n = normalize( Normal_cameraspace );
    \\    vec3 l = normalize( LightDirection_cameraspace );   
    \\      
    \\    float cosTheta = clamp( dot( n,l ), 0,1 );
    \\
    \\    vec3 E = normalize( EyeDirection_cameraspace );
    \\
    \\    vec3 R = reflect(-l,n);
    \\    float cosAlpha = clamp( dot( E,R ), 0,1 );
    \\
    \\    color = MaterialAmbientColor + 
    \\    MaterialDiffuseColor * LightColor * LightPower * cosTheta / (distance*distance) +
    \\    MaterialSpecularColor * LightColor * LightPower * pow(cosAlpha,5) / (distance*distance);
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
