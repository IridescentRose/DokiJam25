const c = @import("consts.zig");
const world = @import("world.zig");

pub const AABB = extern struct {
    const STEP_INCREMENT: f32 = 0.125;
    const MAX_STEP_HEIGHT: f32 = 1.0;
    const SKIN: f32 = 0.001;

    aabb_size: [3]f32,
    can_step: bool,

    const Self = @This();

    pub fn get_min_pos(self: *const Self, new_pos: [3]f32) [3]f32 {
        return [_]f32{
            @floor((new_pos[0] - self.aabb_size[0]) * c.SUB_BLOCKS_PER_BLOCK),
            @floor((new_pos[1]) * c.SUB_BLOCKS_PER_BLOCK),
            @floor((new_pos[2] - self.aabb_size[2]) * c.SUB_BLOCKS_PER_BLOCK),
        };
    }

    pub fn get_max_pos(self: *const Self, new_pos: [3]f32) [3]f32 {
        return [_]f32{
            @floor((new_pos[0] + self.aabb_size[0]) * c.SUB_BLOCKS_PER_BLOCK),
            @floor((new_pos[1] + self.aabb_size[1] * 2) * c.SUB_BLOCKS_PER_BLOCK),
            @floor((new_pos[2] + self.aabb_size[2]) * c.SUB_BLOCKS_PER_BLOCK),
        };
    }

    pub fn can_walk_through(coord: [3]isize) bool {
        const material = world.get_voxel(coord);
        return material == .Air or material == .Water or material == .StillWater or material == .Leaf or material == .Crop or material == .Grass or material == .Fire or material == .Ash;
    }

    // Returns true if the AABB is clear at the given position
    // pos is the center of the AABB in world space (not sub-voxel space)
    fn aabb_clear_at(self: *const Self, pos: [3]f32) bool {
        const minp = self.get_min_pos(pos);
        const maxp = self.get_max_pos(pos);

        const ix0: isize = @intFromFloat(minp[0]);
        const iy0: isize = @intFromFloat(minp[1]);
        const iz0: isize = @intFromFloat(minp[2]);

        const ix1: isize = @intFromFloat(maxp[0]);
        const iy1: isize = @intFromFloat(maxp[1]);
        const iz1: isize = @intFromFloat(maxp[2]);

        var x: isize = ix0;
        while (x <= ix1) : (x += 1) {
            var y: isize = iy0;
            while (y <= iy1) : (y += 1) {
                var z: isize = iz0;
                while (z <= iz1) : (z += 1) {
                    if (!can_walk_through(.{ x, y, z })) return false;
                }
            }
        }
        return true;
    }

    // Updates the position and velocity based on collisions with the world
    // new_pos and vel are both in world space (not sub-voxel space)
    // Modifies new_pos and vel in place
    pub fn collide_aabb_with_world(self: *const Self, new_pos: *[3]f32, vel: *[3]f32, on_ground: *bool) void {
        // Recomputed wholesale after each axis to handle corner cases
        on_ground.* = false;

        // Y
        {
            const minp = self.get_min_pos(new_pos.*);
            const maxp = self.get_max_pos(new_pos.*);

            const testY: f32 = if (vel[1] > 0) maxp[1] else if (vel[1] < 0) minp[1] else 0;

            if (testY != 0) {
                const ix0: isize = @intFromFloat(minp[0]);
                const iz0: isize = @intFromFloat(minp[2]);
                const ix1: isize = @intFromFloat(maxp[0]);
                const iz1: isize = @intFromFloat(maxp[2]);

                var x: isize = ix0;
                var hit: bool = false;
                while (x <= ix1 and !hit) : (x += 1) {
                    var z: isize = iz0;
                    while (z <= iz1) : (z += 1) {
                        const coord = [_]isize{
                            x,
                            @intFromFloat(testY),
                            z,
                        };
                        if (!can_walk_through(coord)) {
                            if (vel[1] > 0) {
                                // Ceiling
                                new_pos[1] = (@as(f32, @floatFromInt(coord[1])) / c.SUB_BLOCKS_PER_BLOCK) - SKIN - self.aabb_size[1] * 2;
                                vel[1] = 0;
                            } else {
                                // Ground
                                new_pos[1] = (@as(f32, @floatFromInt(coord[1] + 1)) / c.SUB_BLOCKS_PER_BLOCK) + SKIN;
                                vel[1] = 0;
                                // don't set on_ground here; we'll probe after all axes
                            }
                            hit = true;
                            break;
                        }
                    }
                }
            }
        }

        // X
        var has_stepped: bool = false;
        {
            const minp = self.get_min_pos(new_pos.*);
            const maxp = self.get_max_pos(new_pos.*);

            const testX: f32 = if (vel[0] > 0) maxp[0] else if (vel[0] < 0) minp[0] else 0;

            if (testX != 0) {
                const iy0: isize = @intFromFloat(minp[1]);
                const iz0: isize = @intFromFloat(minp[2]);
                const iy1: isize = @intFromFloat(maxp[1]);
                const iz1: isize = @intFromFloat(maxp[2]);

                var y: isize = iy0;
                var collided: bool = false;

                while (y <= iy1 and !collided) : (y += 1) {
                    var z: isize = iz0;
                    while (z <= iz1) : (z += 1) {
                        const coord = [_]isize{
                            @intFromFloat(testX),
                            y,
                            z,
                        };

                        if (!can_walk_through(coord)) {
                            // Try stepping if allowed and not already stepped this frame
                            if (!has_stepped and self.can_step) {
                                var s: f32 = STEP_INCREMENT;
                                var stepped: bool = false;
                                while (s <= MAX_STEP_HEIGHT) : (s += STEP_INCREMENT) {
                                    const raised_pos = [_]f32{ new_pos[0], new_pos[1] + s, new_pos[2] };
                                    if (aabb_clear_at(self, raised_pos)) {
                                        // Accept the step: raise Y, keep integrated X (no clamp/no zero)
                                        new_pos[1] += s;
                                        has_stepped = true;
                                        stepped = true;
                                        break;
                                    }
                                }
                                if (stepped) break; // resolved by stepping; keep going without clamping
                            }

                            // Clamp to the face and zero X velocity (only if step failed)
                            if (vel[0] > 0 and !has_stepped) {
                                new_pos[0] = (@as(f32, @floatFromInt(coord[0])) / c.SUB_BLOCKS_PER_BLOCK) - self.aabb_size[0] - SKIN;
                                vel[0] = 0;
                            } else if (vel[0] < 0 and !has_stepped) {
                                new_pos[0] = (@as(f32, @floatFromInt(coord[0] + 1)) / c.SUB_BLOCKS_PER_BLOCK) + self.aabb_size[0] + SKIN;
                                vel[0] = 0;
                            }

                            collided = true;
                            break;
                        }
                    }
                }
            }
        }

        // Z
        {
            const minp = self.get_min_pos(new_pos.*);
            const maxp = self.get_max_pos(new_pos.*);

            const testZ: f32 = if (vel[2] > 0) maxp[2] else if (vel[2] < 0) minp[2] else 0;

            if (testZ != 0) {
                const ix0: isize = @intFromFloat(minp[0]);
                const iy0: isize = @intFromFloat(minp[1]);
                const ix1: isize = @intFromFloat(maxp[0]);
                const iy1: isize = @intFromFloat(maxp[1]);

                var x: isize = ix0;
                var collided: bool = false;

                while (x <= ix1 and !collided) : (x += 1) {
                    var y: isize = iy0;
                    while (y <= iy1) : (y += 1) {
                        const coord = [_]isize{
                            x,
                            y,
                            @intFromFloat(testZ),
                        };

                        if (!can_walk_through(coord)) {
                            // Try stepping if allowed and not already stepped this frame
                            if (!has_stepped and self.can_step) {
                                var s: f32 = STEP_INCREMENT;
                                var stepped: bool = false;
                                while (s <= MAX_STEP_HEIGHT) : (s += STEP_INCREMENT) {
                                    const raised_pos = [_]f32{ new_pos[0], new_pos[1] + s, new_pos[2] };
                                    if (aabb_clear_at(self, raised_pos)) {
                                        // Accept the step: raise Y, keep integrated Z
                                        new_pos[1] += s;
                                        has_stepped = true;
                                        stepped = true;
                                        break;
                                    }
                                }
                                if (stepped) break; // resolved by stepping; keep going without clamping
                            }

                            // Clamp to the face and zero Z velocity (only if step failed)
                            if (vel[2] > 0 and !has_stepped) {
                                new_pos[2] = (@as(f32, @floatFromInt(coord[2])) / c.SUB_BLOCKS_PER_BLOCK) - self.aabb_size[2] - SKIN;
                                vel[2] = 0;
                            } else if (vel[2] < 0 and !has_stepped) {
                                new_pos[2] = (@as(f32, @floatFromInt(coord[2] + 1)) / c.SUB_BLOCKS_PER_BLOCK) + self.aabb_size[2] + SKIN;
                                vel[2] = 0;
                            }

                            collided = true;
                            break;
                        }
                    }
                }
            }
        }

        {
            const probe_pos = [_]f32{ new_pos[0], new_pos[1] - SKIN * 2.0, new_pos[2] };
            on_ground.* = !aabb_clear_at(self, probe_pos);
        }
    }
};
