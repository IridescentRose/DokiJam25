const std = @import("std");
const ecs = @import("../entity/ecs.zig");
const components = @import("../entity/components.zig");
const zm = @import("zmath");
const c = @import("../consts.zig");
const world = @import("../world.zig");

const TERMINAL_VELOCITY = -10.0; // Dragoon terminal velocity
const GRAVITY = -9.8; // Dragoon is light!
const MOVE_SPEED = 1.0;

pub fn create(position: [3]f32, rotation: [3]f32, model: components.ModelComponent) !ecs.Entity {
    const entity = try ecs.create_entity(.dragoon_builder);

    // Initialize components
    try entity.add_component(.transform, components.TransformComponent.new());
    try entity.add_component(.model, model);
    try entity.add_component(.aabb, .{ .aabb_size = [_]f32{ 0.125, 0.125, 0.125 }, .can_step = true });
    try entity.add_component(.velocity, @splat(0));
    try entity.add_component(.on_ground, false);
    try entity.add_component(.health, 10);
    try entity.add_component(.timer, std.time.milliTimestamp() + std.time.ms_per_s * 1); // Initialize timer to 0

    // Set initial position and rotation
    const transform = entity.get_ptr(.transform);
    transform.pos = position;
    transform.rot = rotation;
    transform.scale = @splat(1.0 / 5.0);
    transform.size = [_]f32{ 20.0, -4.01, 20.0 }; // Dragoon size

    return entity;
}

pub fn update(self: ecs.Entity, dt: f32) void {
    const mask = self.get(.mask);
    const can_update = mask.transform and mask.velocity and mask.on_ground;

    if (!can_update) return; // Ensure we have the necessary components

    const curr_pos = [_]isize{
        @intFromFloat(self.get(.transform).pos[0]),
        @intFromFloat(@max(@min(self.get(.transform).pos[1], 62.0), 0)), // Clamp y to world height
        @intFromFloat(self.get(.transform).pos[2]),
    };

    // Ensure the dragoon is within the world bounds
    if (!world.is_in_world([_]isize{ curr_pos[0] * c.SUB_BLOCKS_PER_BLOCK, curr_pos[1] * c.SUB_BLOCKS_PER_BLOCK, curr_pos[2] * c.SUB_BLOCKS_PER_BLOCK })) return;

    const time = self.get_ptr(.timer);
    if (std.time.milliTimestamp() >= time.*) { // Wait for the timer to expire
        // Update timer + 5s
        time.* = std.time.milliTimestamp() + std.time.ms_per_s * 3;
    }

    var velocity = self.get_ptr(.velocity);

    // Because time only updates every 5 seconds, we actually get a random velocity every 5 seconds.
    // This is to prevent the dragoon from switching directions too quickly.
    var rng = std.Random.DefaultPrng.init(@bitCast(time.*));

    const size: f32 = @floatFromInt(std.math.maxInt(i16));

    const x: f32 = @floatFromInt(rng.random().intRangeAtMost(i16, std.math.minInt(i16), std.math.maxInt(i16)));
    const z: f32 = @floatFromInt(rng.random().intRangeAtMost(i16, std.math.minInt(i16), std.math.maxInt(i16)));

    velocity[0] = x / size; // Random x velocity
    velocity[2] = z / size; // Random z velocity

    // Ensure we have a non-zero velocity in the x and z directions
    if (velocity[0] == 0.0 and velocity[2] == 0.0) {
        velocity[0] = 1.0; // Default to 1.0 in x direction
        velocity[2] = 1.0; // Default to 1.0 in z direction
    }

    velocity[1] += GRAVITY * dt;

    const THRESHOLD: f32 = 0.1; // Movement threshold
    if (velocity[0] * velocity[0] + velocity[2] * velocity[2] > THRESHOLD * THRESHOLD) {
        const norm = zm.normalize3([_]f32{ velocity[0], 0.0, velocity[2], 0.0 }) * @as(@Vector(4, f32), @splat(MOVE_SPEED)); // 5 units/sec move speed
        velocity[0] = norm[0];
        velocity[2] = norm[2];

        // Update rotation based on movement direction
        self.get_ptr(.transform).rot[1] = std.math.radiansToDegrees(std.math.atan2(velocity[0], velocity[2])) + 180.0;
    }

    if (velocity[1] < TERMINAL_VELOCITY) velocity[1] = TERMINAL_VELOCITY;
}
