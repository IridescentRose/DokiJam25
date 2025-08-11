const std = @import("std");
const assert = std.debug.assert;
const util = @import("../../core/util.zig");
const components = @import("components.zig");
const gfx = @import("../../gfx/gfx.zig");

pub const Entity = struct {
    id: u32,

    pub fn do_physics(self: Entity, dt: f32) void {
        const can_do_physics = masks.items[self.id].velocity and masks.items[self.id].aabb and masks.items[self.id].transform and masks.items[self.id].on_ground;
        if (!can_do_physics) return;

        const vel = self.get_ptr(.velocity);

        var new_pos = [_]f32{
            self.get(.transform).pos[0] + vel[0] * dt,
            self.get(.transform).pos[1] + vel[1] * dt,
            self.get(.transform).pos[2] + vel[2] * dt,
        };

        self.get(.aabb).collide_aabb_with_world(&new_pos, vel, self.get_ptr(.on_ground));
        self.get_ptr(.transform).pos = new_pos;

        // Remove any velocity in the x and z directions to prevent sliding
        // TODO: Make this configurable.
        // vel[0] = 0;
        // vel[2] = 0;
    }

    pub const MAX_ENTITY_DRAW_DISTANCE = 40.0; // Maximum distance to draw entities
    pub fn draw(self: Entity, shadow: bool, center: [3]f32) void {
        const can_draw = masks.items[self.id].model and masks.items[self.id].transform;
        if (!can_draw) return;

        const pos = self.get(.transform).pos;
        const delta = [_]f32{
            pos[0] - center[0],
            pos[1] - center[1],
            pos[2] - center[2],
        };

        if (delta[0] * delta[0] + delta[1] * delta[1] + delta[2] * delta[2] > MAX_ENTITY_DRAW_DISTANCE * MAX_ENTITY_DRAW_DISTANCE) {
            return; // Too far away to draw
        }

        if (shadow) {
            gfx.shader.use_shadow_shader();
            gfx.shader.set_shadow_model(self.get(.transform).get_matrix());
            self.get_ptr(.model).draw();
        } else {
            gfx.shader.use_render_shader();
            gfx.shader.set_model(self.get(.transform).get_matrix());
            self.get_ptr(.model).draw();
        }
    }

    pub fn get(entity: Entity, comptime comp_type: ComponentType) ComponentTypes[@intFromEnum(comp_type)] {
        return get_ptr(entity, comp_type).*;
    }

    pub fn get_ptr(entity: Entity, comptime comp_type: ComponentType) *ComponentTypes[@intFromEnum(comp_type)] {
        assert(initialized);
        assert(entity.id < transforms.items.len);
        // Ensure the entity has the requested component.
        if (comp_type != .mask) {
            assert(@field(masks.items[entity.id], @tagName(comp_type)));
        }

        switch (comp_type) {
            .mask => return &masks.items[entity.id],
            .kind => return &kinds.items[entity.id],
            .transform => return &transforms.items[entity.id],
            .model => return &models.items[entity.id],
            .aabb => return &aabbs.items[entity.id],
            .velocity => return &velocities.items[entity.id],
            .on_ground => return &onGrounds.items[entity.id],
            .health => return &healths.items[entity.id],
            .timer => return &timers.items[entity.id],
        }
    }

    pub fn add_component(entity: Entity, comptime comp_type: ComponentType, component: ComponentTypes[@intFromEnum(comp_type)]) !void {
        assert(initialized);
        assert(entity.id < transforms.items.len);

        // TODO: Make a mapping of arrays to component types to avoid this switch.

        const id = entity.id;
        const T = @TypeOf(component);

        if (T == components.TransformComponent) {
            transforms.items[id] = component;
            masks.items[id].transform = true;
        } else if (T == components.ModelComponent) {
            models.items[id] = component;
            masks.items[id].model = true;
        } else if (T == components.AABBComponent) {
            aabbs.items[id] = component;
            masks.items[id].aabb = true;
        } else if (T == components.VelocityComponent) {
            velocities.items[id] = component;
            masks.items[id].velocity = true;
        } else if (T == components.OnGroundComponent) {
            onGrounds.items[id] = component;
            masks.items[id].on_ground = true;
        } else if (T == components.HealthComponent) {
            healths.items[id] = component;
            masks.items[id].health = true;
        } else if (T == i64) {
            timers.items[id] = component;
            masks.items[id].timer = true;
        } else if (T == EntityKind) {
            kinds.items[id] = component;
            masks.items[id].kind = true; // Kind is always set.
        } else {
            return error.InvalidComponentType;
        }
    }
};

var initialized = false;

pub const EntityKind = enum(u8) {
    none = 0,
    player = 1,
    dragoon = 2,
    tomato = 3,
};

pub const ComponentType = enum(u8) {
    mask = 0,
    kind = 1,
    transform = 2,
    model = 3,
    aabb = 4,
    velocity = 5,
    on_ground = 6,
    health = 7,
    timer = 8,
};

const ComponentTypes = [_]type{
    Mask,
    EntityKind,
    components.TransformComponent,
    components.ModelComponent,
    components.AABBComponent,
    components.VelocityComponent,
    components.OnGroundComponent,
    components.HealthComponent,
    i64,
};

pub var active_entities: std.ArrayListUnmanaged(Entity) = undefined;
var kinds: std.ArrayListUnmanaged(EntityKind) = undefined;
var transforms: std.ArrayListUnmanaged(components.TransformComponent) = undefined;
var models: std.ArrayListUnmanaged(components.ModelComponent) = undefined;
var aabbs: std.ArrayListUnmanaged(components.AABBComponent) = undefined;
var velocities: std.ArrayListUnmanaged(components.VelocityComponent) = undefined;
var onGrounds: std.ArrayListUnmanaged(components.OnGroundComponent) = undefined;
var healths: std.ArrayListUnmanaged(components.HealthComponent) = undefined;
var timers: std.ArrayListUnmanaged(i64) = undefined;

pub const Mask = packed struct(u32) {
    kind: bool = true, // By default, all entities have a kind.
    transform: bool = false,
    model: bool = false,
    aabb: bool = false,
    velocity: bool = false,
    on_ground: bool = false,
    health: bool = false,
    timer: bool = false,
    reserved: u24 = 0,
};

var masks: std.ArrayListUnmanaged(Mask) = undefined;

pub fn init() !void {
    assert(!initialized);

    active_entities = try std.ArrayListUnmanaged(Entity).initCapacity(util.allocator(), 32);
    masks = try std.ArrayListUnmanaged(Mask).initCapacity(util.allocator(), 32);
    kinds = try std.ArrayListUnmanaged(EntityKind).initCapacity(util.allocator(), 32);
    transforms = try std.ArrayListUnmanaged(components.TransformComponent).initCapacity(util.allocator(), 32);
    models = try std.ArrayListUnmanaged(components.ModelComponent).initCapacity(util.allocator(), 32);
    aabbs = try std.ArrayListUnmanaged(components.AABBComponent).initCapacity(util.allocator(), 32);
    velocities = try std.ArrayListUnmanaged(components.VelocityComponent).initCapacity(util.allocator(), 32);
    onGrounds = try std.ArrayListUnmanaged(components.OnGroundComponent).initCapacity(util.allocator(), 32);
    healths = try std.ArrayListUnmanaged(components.HealthComponent).initCapacity(util.allocator(), 32);
    timers = try std.ArrayListUnmanaged(i64).initCapacity(util.allocator(), 32);

    initialized = true;
    assert(initialized);
}

pub fn deinit() void {
    assert(initialized);

    active_entities.deinit(util.allocator());
    transforms.deinit(util.allocator());
    models.deinit(util.allocator());
    aabbs.deinit(util.allocator());
    velocities.deinit(util.allocator());
    onGrounds.deinit(util.allocator());
    healths.deinit(util.allocator());
    masks.deinit(util.allocator());
    kinds.deinit(util.allocator());
    timers.deinit(util.allocator());

    initialized = false;
    assert(!initialized);
}

pub fn create_entity(kind: EntityKind) !Entity {
    assert(initialized);

    const id = @as(u32, @intCast(transforms.items.len));
    try transforms.append(util.allocator(), components.TransformComponent.new());
    try models.append(util.allocator(), undefined);
    try aabbs.append(util.allocator(), undefined);
    try velocities.append(util.allocator(), @splat(0));
    try onGrounds.append(util.allocator(), false);
    try healths.append(util.allocator(), 0);
    try kinds.append(util.allocator(), kind);
    try masks.append(util.allocator(), .{ .kind = true }); // Kind is always set.
    try timers.append(util.allocator(), 0);
    try active_entities.append(util.allocator(), .{ .id = id });

    return .{
        .id = id,
    };
}
