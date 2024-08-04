const std = @import("std");
const gl = @import("zgl");
const glfw = @import("glfw");

const glfw_log = std.log.scoped(.glfw);
const gl_log = std.log.scoped(.gl);

fn logGLFWError(error_code: c_int, description: [*:0]const u8) callconv(.C) void {
    glfw_log.err("{}: {s}\n", .{ error_code, description });
}

pub fn main() !void {
    
    _ = glfw.setErrorCallback(logGLFWError);

    var major: i32 = 0;
    var minor: i32 = 0;
    var rev: i32 = 0;

    glfw.getVersion(&major, &minor, &rev);
    std.debug.print("GLFW {}.{}.{}\n", .{ major, minor, rev });

    try glfw.init();
    defer glfw.terminate();

    std.debug.print("GLFW Init Succeeded.\n", .{});

    const window: *glfw.Window = try glfw.createWindow(800, 640, "Hello World", null, null);
    defer glfw.destroyWindow(window);

    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    const proc = glfw.getProcAddress("");
    std.debug.print("GLFW proc address: {*}\n", .{proc});
    proc.?();

    while (!glfw.windowShouldClose(window)) {
        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
        }

        glfw.pollEvents();
    }
}
