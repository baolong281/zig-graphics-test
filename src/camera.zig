const std = @import("std");
const za = @import("zalgebra");
const glfw = @import("glfw");
const Vec3 = za.Vec3;

const WIDTH = @import("main.zig").WIDTH;
const HEIGHT = @import("main.zig").HEIGHT;

pub const Controls = struct {
    window: *glfw.Window,
    position: Vec3,
    horizontal_angle: f32,
    vertical_angle: f32,
    fov: f32,
    speed: f32,
    mouse_speed: f32,
    last_time: f64,
    up: Vec3,
    direction: Vec3,

    pub fn updateMatricesFromInput(self: *Controls) void {
        var x_pos: f64 = 0;
        var y_pos: f64 = 0;

        glfw.getCursorPos(self.window, &x_pos, &y_pos);
        glfw.setCursorPos(self.window, WIDTH / 2, HEIGHT / 2);

        const delta_time = glfw.getTime() - self.last_time;
        const delta_time_f32: f32 = @floatCast(delta_time);
        self.last_time = glfw.getTime();

        // calculate new angles in spherical coordinates
        const x_pos_int: i32 = @intFromFloat(x_pos);
        const half_width: f32 = @as(f32, @floatFromInt(WIDTH)) / 2.0;
        const delta_x: f32 = half_width - @as(f32, @floatFromInt(x_pos_int));
        self.horizontal_angle += self.mouse_speed * delta_time_f32 * delta_x;

        const y_pos_int: i32 = @intFromFloat(y_pos);
        const half_height: f32 = @as(f32, @floatFromInt(HEIGHT)) / 2.0;
        const delta_y: f32 = half_height - @as(f32, @floatFromInt(y_pos_int));
        self.vertical_angle += self.mouse_speed * delta_time_f32 * delta_y;

        if (self.vertical_angle > 1.5) {
            self.vertical_angle = 1.5;
        } else if (self.vertical_angle < -1.5) {
            self.vertical_angle = -1.5;
        }

        // convert those angles to cartesian coordinates
        // r is just 1 here
        self.direction = Vec3.new(
            @cos(self.vertical_angle) * @sin(self.horizontal_angle),
            @sin(self.vertical_angle),
            @cos(self.vertical_angle) * @cos(self.horizontal_angle),
        );

        // we don't have any roll so y is just 0
        const right = Vec3.new(
            @sin(self.horizontal_angle - 3.14 / 2.0),
            0,
            @cos(self.horizontal_angle - 3.14 / 2.0),
        );

        // up is perpendicular to direction and right so we just cross
        self.up = right.cross(self.direction);

        // change position on key press
        if (glfw.getKey(self.window, glfw.KeyW) == glfw.Press) {
            self.position = self.position.add(self.direction.scale(self.speed * delta_time_f32));
        }

        if (glfw.getKey(self.window, glfw.KeyS) == glfw.Press) {
            self.position = self.position.sub(self.direction.scale(self.speed * delta_time_f32));
        }

        if (glfw.getKey(self.window, glfw.KeyA) == glfw.Press) {
            self.position = self.position.sub(right.scale(self.speed * delta_time_f32));
        }

        if (glfw.getKey(self.window, glfw.KeyD) == glfw.Press) {
            self.position = self.position.add(right.scale(self.speed * delta_time_f32));
        }

        if (glfw.getKey(self.window, glfw.KeySpace) == glfw.Press) {
            self.position = self.position.add(Vec3.new(0, 1, 0).scale(self.speed * delta_time_f32));
        }

        if (glfw.getKey(self.window, glfw.KeyLeftControl) == glfw.Press) {
            self.position = self.position.sub(Vec3.new(0, 1, 0).scale(self.speed * delta_time_f32));
        }
    }

    pub fn getProjectionMatrix(self: *Controls) za.Mat4 {
        return za.perspective(self.fov, @as(f32, WIDTH / HEIGHT), 0.1, 400.0);
    }

    pub fn getViewMatrix(self: *Controls) za.Mat4 {
        // the camera looks at the position + the direction
        return za.lookAt(self.position, self.position.add(self.direction), self.up);
    }

    pub fn new(window: *glfw.Window) Controls {
        return Controls{
            .window = window,
            .position = Vec3.new(0, 0, 3),
            .horizontal_angle = 3.14,
            .vertical_angle = 0.0,
            .fov = 70.0,
            .speed = 5.0,
            .mouse_speed = 0.035,
            .last_time = glfw.getTime(),
            .up = Vec3.new(0, 1, 0),
            .direction = Vec3.new(0, 0, 1),
        };
    }
};
