const Transform = @import("../../gfx/transform.zig");
const Voxel = @import("../voxel.zig");
const AABB = @import("../aabb.zig");

pub const TransformComponent = Transform;
pub const ModelComponent = Voxel;

pub const AABBComponent = AABB;
pub const VelocityComponent = @Vector(3, f32);

pub const OnGroundComponent = bool;
pub const HealthComponent = u8;
pub const HungerComponent = u8;
