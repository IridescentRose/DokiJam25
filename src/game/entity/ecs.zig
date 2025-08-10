const std = @import("std");
const assert = std.debug.assert;
const util = @import("../../core/util.zig");
const components = @import("components.zig");

pub const Entity = struct {
    id: u32,

    pub fn get(entity: Entity, comptime comp_type: ComponentType) ComponentTypes[@intFromEnum(comp_type)] {
        return get_ptr(entity, comp_type).*;
    }

    pub fn get_ptr(entity: Entity, comptime comp_type: ComponentType) *ComponentTypes[@intFromEnum(comp_type)] {
        assert(initialized);
        assert(entity.id < transforms.items.len);
        // Ensure the entity has the requested component.
        assert(@field(masks.items[entity.id], @tagName(comp_type)));

        switch (comp_type) {
            .transform => return &transforms.items[entity.id],
            .model => return &models.items[entity.id],
            .aabb => return &aabbs.items[entity.id],
            .velocity => return &velocities.items[entity.id],
            .on_ground => return &onGrounds.items[entity.id],
            .health => return &healths.items[entity.id],
        }
    }

    pub fn add_component(entity: Entity, comptime comp_type: ComponentType, component: ComponentTypes[@intFromEnum(comp_type)]) !void {
        assert(initialized);
        assert(entity.id < transforms.items.len);

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
        } else {
            return error.InvalidComponentType;
        }
    }
};

var initialized = false;

pub const ComponentType = enum(u8) {
    transform = 0,
    model = 1,
    aabb = 2,
    velocity = 3,
    on_ground = 4,
    health = 5,
};

const ComponentTypes = [_]type{
    components.TransformComponent,
    components.ModelComponent,
    components.AABBComponent,
    components.VelocityComponent,
    components.OnGroundComponent,
    components.HealthComponent,
};

var transforms: std.ArrayListUnmanaged(components.TransformComponent) = undefined;
var models: std.ArrayListUnmanaged(components.ModelComponent) = undefined;
var aabbs: std.ArrayListUnmanaged(components.AABBComponent) = undefined;
var velocities: std.ArrayListUnmanaged(components.VelocityComponent) = undefined;
var onGrounds: std.ArrayListUnmanaged(components.OnGroundComponent) = undefined;
var healths: std.ArrayListUnmanaged(components.HealthComponent) = undefined;

const Mask = packed struct(u32) {
    transform: bool = false,
    model: bool = false,
    aabb: bool = false,
    velocity: bool = false,
    on_ground: bool = false,
    health: bool = false,
    reserved: u26 = 0,

    pub fn toBits(self: Mask) u32 {
        return @as(u32, @bitCast(self));
    }
};

var masks: std.ArrayListUnmanaged(Mask) = undefined;

pub fn init() !void {
    assert(!initialized);

    transforms = try std.ArrayListUnmanaged(components.TransformComponent).initCapacity(util.allocator(), 32);
    models = try std.ArrayListUnmanaged(components.ModelComponent).initCapacity(util.allocator(), 32);
    aabbs = try std.ArrayListUnmanaged(components.AABBComponent).initCapacity(util.allocator(), 32);
    velocities = try std.ArrayListUnmanaged(components.VelocityComponent).initCapacity(util.allocator(), 32);
    onGrounds = try std.ArrayListUnmanaged(components.OnGroundComponent).initCapacity(util.allocator(), 32);
    healths = try std.ArrayListUnmanaged(components.HealthComponent).initCapacity(util.allocator(), 32);
    masks = try std.ArrayListUnmanaged(Mask).initCapacity(util.allocator(), 32);

    initialized = true;
    assert(initialized);
}

pub fn deinit() void {
    assert(initialized);

    transforms.deinit(util.allocator());
    models.deinit(util.allocator());
    aabbs.deinit(util.allocator());
    velocities.deinit(util.allocator());
    onGrounds.deinit(util.allocator());
    healths.deinit(util.allocator());
    masks.deinit(util.allocator());

    initialized = false;
    assert(!initialized);
}

pub fn create_entity() !Entity {
    assert(initialized);

    const id = @as(u32, @intCast(transforms.items.len));
    try transforms.append(util.allocator(), components.TransformComponent.new());
    try models.append(util.allocator(), undefined);
    try aabbs.append(util.allocator(), undefined);
    try velocities.append(util.allocator(), @splat(0));
    try onGrounds.append(util.allocator(), false);
    try healths.append(util.allocator(), 0);

    // No components are set by default, so we use a mask of 0.
    try masks.append(util.allocator(), .{});

    return .{
        .id = id,
    };
}
