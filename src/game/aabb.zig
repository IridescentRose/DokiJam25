const c = @import("consts.zig");
const world = @import("world.zig");

const STEP_INCREMENT = 0.125;
const MAX_STEP_HEIGHT = 1.0;

aabb_size: [3]f32,
can_step: bool,

const Self = @This();

pub fn get_min_pos(self: *Self, new_pos: [3]f32) [3]f32 {
    return [_]f32{
        @floor((new_pos[0] - self.aabb_size[0]) * c.SUB_BLOCKS_PER_BLOCK),
        @floor((new_pos[1]) * c.SUB_BLOCKS_PER_BLOCK),
        @floor((new_pos[2] - self.aabb_size[2]) * c.SUB_BLOCKS_PER_BLOCK),
    };
}

pub fn get_max_pos(self: *Self, new_pos: [3]f32) [3]f32 {
    return [_]f32{
        @ceil((new_pos[0] + self.aabb_size[0]) * c.SUB_BLOCKS_PER_BLOCK),
        @ceil((new_pos[1] + self.aabb_size[1] * 2) * c.SUB_BLOCKS_PER_BLOCK),
        @ceil((new_pos[2] + self.aabb_size[2]) * c.SUB_BLOCKS_PER_BLOCK),
    };
}

pub fn can_walk_through(coord: [3]isize) bool {
    const material = world.get_voxel(coord);
    return material == .Air or material == .Water or material == .StillWater or material == .Leaf or material == .Grass or material == .Fire or material == .Ash;
}

// Updates the position and velocity based on collisions with the world
// new_pos and vel are both in world space (not sub-voxel space)
// Modifies new_pos and vel in place
pub fn collide_aabb_with_world(self: *Self, new_pos: *[3]f32, vel: *[3]f32, on_ground: *bool) void {
    {
        const min_pos = get_min_pos(self, new_pos.*);
        const max_pos = get_max_pos(self, new_pos.*);

        const testY = if (vel[1] > 0) max_pos[1] else if (vel[1] < 0) min_pos[1] else 0;

        if (testY != 0) {
            const max_x: isize = @intFromFloat(max_pos[0]);
            const max_z: isize = @intFromFloat(max_pos[2]);

            var x: isize = @intFromFloat(min_pos[0]);
            while (x < max_x) : (x += 1) {
                var z: isize = @intFromFloat(min_pos[2]);

                while (z < max_z) : (z += 1) {
                    const coord = [_]isize{
                        x,
                        @intFromFloat(testY),
                        z,
                    };

                    if (!can_walk_through(coord)) {
                        if (vel[1] > 0) {
                            new_pos[1] = @as(f32, @floatFromInt(coord[1] - 1)) / c.SUB_BLOCKS_PER_BLOCK;
                            vel[1] = 0;
                        }
                        // If moving down, hit ground
                        else if (vel[1] < 0) {
                            new_pos[1] = (@as(f32, @floatFromInt(coord[1] + 1))) / c.SUB_BLOCKS_PER_BLOCK;
                            vel[1] = 0;
                            on_ground.* = true;
                        }

                        break;
                    }
                }
            }
        }
    }

    // X axis

    var has_stepped: bool = false;

    {
        const min_pos = get_min_pos(self, new_pos.*);
        const max_pos = get_max_pos(self, new_pos.*);

        const testX = if (vel[0] > 0) max_pos[0] else if (vel[0] < 0) min_pos[0] else 0;

        if (testX != 0) {
            const max_y: isize = @intFromFloat(max_pos[1]);
            const max_z: isize = @intFromFloat(max_pos[2]);

            var y: isize = @intFromFloat(min_pos[1]);
            while (y < max_y) : (y += 1) {
                var z: isize = @intFromFloat(min_pos[2]);

                while (z < max_z) : (z += 1) {
                    const coord = [_]isize{
                        @intFromFloat(testX),
                        y,
                        z,
                    };

                    if (!can_walk_through(coord)) {
                        if (on_ground.* and !has_stepped and self.can_step) {
                            // try small increments up to MAX_STEP_HEIGHT
                            var stepped = false;
                            var s: f32 = STEP_INCREMENT;
                            while (s <= MAX_STEP_HEIGHT) : (s += STEP_INCREMENT) {
                                // sample the voxel at the would-be position,
                                // but raised by s
                                const worldX = (@as(f32, testX) / c.SUB_BLOCKS_PER_BLOCK);
                                const worldY = new_pos[1] + s;
                                const worldZ = new_pos[2];

                                const ix: isize = @intFromFloat(@floor(worldX * c.SUB_BLOCKS_PER_BLOCK));
                                const iy: isize = @intFromFloat(@floor(worldY * c.SUB_BLOCKS_PER_BLOCK));
                                const iz: isize = @intFromFloat(@floor(worldZ * c.SUB_BLOCKS_PER_BLOCK));

                                if (can_walk_through(.{ ix, iy, iz })) {
                                    // looks clear at this step height
                                    new_pos[1] += s;
                                    // now re-try the X collision at the higher Y:

                                    if (vel[0] > 0) {
                                        new_pos[0] = @as(f32, @floatFromInt(coord[0] - 1)) / c.SUB_BLOCKS_PER_BLOCK - self.aabb_size[0];
                                    } else if (vel[0] < 0) {
                                        new_pos[0] = (@as(f32, @floatFromInt(coord[0] + 1))) / c.SUB_BLOCKS_PER_BLOCK + self.aabb_size[0];
                                    }
                                    vel[0] = 0;
                                    stepped = true;
                                    has_stepped = true;
                                    break;
                                }
                            }
                            if (stepped) break; // we’ve stepped up and resolved X
                        }
                        // If moving right, hit right wall
                        if (vel[0] > 0) {
                            new_pos[0] = @as(f32, @floatFromInt(coord[0] - 1)) / c.SUB_BLOCKS_PER_BLOCK - self.aabb_size[0];
                            vel[0] = 0;
                        }
                        // If moving left, hit left wall
                        else if (vel[0] < 0) {
                            new_pos[0] = (@as(f32, @floatFromInt(coord[0] + 1))) / c.SUB_BLOCKS_PER_BLOCK + self.aabb_size[0];
                            vel[0] = 0;
                        }

                        break;
                    }
                }
            }
        }
    }

    {
        const min_pos = get_min_pos(self, new_pos.*);
        const max_pos = get_max_pos(self, new_pos.*);

        const testZ = if (vel[2] > 0) max_pos[2] else if (vel[2] < 0) min_pos[2] else 0;

        if (testZ != 0) {
            const max_x: isize = @intFromFloat(max_pos[0]);
            const max_y: isize = @intFromFloat(max_pos[1]);

            var x: isize = @intFromFloat(min_pos[0]);
            while (x < max_x) : (x += 1) {
                var y: isize = @intFromFloat(min_pos[1]);

                while (y < max_y) : (y += 1) {
                    const coord = [_]isize{
                        x,
                        y,
                        @intFromFloat(testZ),
                    };

                    if (!can_walk_through(coord)) {
                        if (on_ground.* and !has_stepped and self.can_step) {
                            // try small increments up to MAX_STEP_HEIGHT
                            var stepped = false;
                            var s: f32 = STEP_INCREMENT;
                            while (s <= MAX_STEP_HEIGHT) : (s += STEP_INCREMENT) {
                                // sample the voxel at the would-be position,
                                // but raised by s
                                const worldX = new_pos[0];
                                const worldY = new_pos[1] + s;
                                const worldZ = (@as(f32, testZ) / c.SUB_BLOCKS_PER_BLOCK);

                                const ix: isize = @intFromFloat(@floor(worldX * c.SUB_BLOCKS_PER_BLOCK));
                                const iy: isize = @intFromFloat(@floor(worldY * c.SUB_BLOCKS_PER_BLOCK));
                                const iz: isize = @intFromFloat(@floor(worldZ * c.SUB_BLOCKS_PER_BLOCK));

                                if (can_walk_through(.{ ix, iy, iz })) {
                                    // looks clear at this step height
                                    new_pos[1] += s;
                                    // now re-try the Z collision at the higher Y:

                                    if (vel[2] > 0) {
                                        new_pos[2] = @as(f32, @floatFromInt(coord[2] - 1)) / c.SUB_BLOCKS_PER_BLOCK - self.aabb_size[2];
                                    } else if (vel[2] < 0) {
                                        new_pos[2] = (@as(f32, @floatFromInt(coord[2] + 1))) / c.SUB_BLOCKS_PER_BLOCK + self.aabb_size[2];
                                    }
                                    vel[2] = 0;
                                    stepped = true;
                                    has_stepped = true;
                                    break;
                                }
                            }
                            if (stepped) break; // we’ve stepped up and resolved Z
                        }

                        // If moving forward, hit front wall
                        if (vel[2] > 0) {
                            new_pos[2] = @as(f32, @floatFromInt(coord[2] - 1)) / c.SUB_BLOCKS_PER_BLOCK - self.aabb_size[2];
                            vel[2] = 0;
                        }
                        // If moving back, hit back wall
                        else if (vel[2] < 0) {
                            new_pos[2] = (@as(f32, @floatFromInt(coord[2] + 1))) / c.SUB_BLOCKS_PER_BLOCK + self.aabb_size[2];
                            vel[2] = 0;
                        }
                        break;
                    }
                }
            }
        }
    }
}
