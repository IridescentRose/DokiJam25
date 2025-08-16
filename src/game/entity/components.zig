const Transform = @import("../../gfx/transform.zig");
const AABB = @import("../aabb.zig");

pub const ModelComponent = @import("../model_manager.zig").ModelID;
pub const TransformComponent = Transform.Transform;

pub const AABBComponent = AABB.AABB;
pub const VelocityComponent = @Vector(3, f32);

pub const OnGroundComponent = bool;
pub const HealthComponent = u8;
pub const InventoryComponent = @import("../inventory.zig").Inventory;
