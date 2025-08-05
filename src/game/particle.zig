const std = @import("std");
const gfx = @import("../gfx/gfx.zig");
const util = @import("../core/util.zig");
const c = @import("consts.zig");
const world = @import("world.zig");
const Transform = @import("../gfx/transform.zig");
const Self = @This();
const gl = @import("../gfx/gl.zig");

pub const Particle = struct {
    pos: [3]f32,
    color: [3]u8,
    vel: [3]f32,
    lifetime: u16,
};

mesh: gfx.ParticleMesh,
transform: Transform,
particles: std.ArrayList(Particle),

pub fn new() !Self {
    var res: Self = .{
        .mesh = try gfx.ParticleMesh.new(),
        .transform = Transform.new(),
        .particles = std.ArrayList(Particle).init(util.allocator()),
    };

    try res.mesh.vertices.appendSlice(util.allocator(), &c.particle_front_face);
    try res.mesh.indices.appendSlice(util.allocator(), &[_]u32{ 0, 1, 2, 2, 3, 0 });

    res.transform.pos = [_]f32{ 0, 2, 0 };

    return res;
}

pub fn add_particle(self: *Self, particle: Particle) !void {
    try self.particles.append(particle);
}

pub fn deinit(self: *Self) void {
    self.mesh.deinit();
    self.particles.deinit();
}

pub fn update(self: *Self) !void {
    self.mesh.instances.clearAndFree(util.allocator());

    for (self.particles.items) |*particle| {
        if (particle.lifetime > 0) {
            try self.mesh.instances.append(util.allocator(), gfx.ParticleMesh.Instance{
                .vert = [_]f32{ particle.pos[0], particle.pos[1], particle.pos[2] },
                .col = particle.color,
            });

            particle.pos[0] += particle.vel[0] * 1.0 / 60.0;
            particle.pos[1] += particle.vel[1] * 1.0 / 60.0;
            particle.pos[2] += particle.vel[2] * 1.0 / 60.0;
            particle.lifetime -= 1;
        }
    }

    var i: usize = self.particles.items.len - 1;
    while (i > 0) : (i -= 1) {
        if (self.particles.items[i].lifetime == 0) {
            _ = self.particles.swapRemove(i);
        }
    }

    self.mesh.update();
}

pub fn draw(self: *Self) void {
    if (self.mesh.indices.items.len != 0) {
        gfx.shader.use_particle_shader();
        gfx.shader.set_part_projview(world.player.camera.get_projview_matrix());
        gfx.shader.set_part_yaw(std.math.degreesToRadians(-world.player.camera.yaw + 90.0));
        gfx.shader.set_part_pitch(std.math.degreesToRadians(0));
        gfx.shader.set_model(self.transform.get_matrix());

        self.mesh.draw();
    }
}
