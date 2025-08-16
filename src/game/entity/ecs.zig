const std = @import("std");
const assert = std.debug.assert;
const util = @import("../../core/util.zig");
const components = @import("components.zig");
const gfx = @import("../../gfx/gfx.zig");
const c = @import("../consts.zig");
const mm = @import("../model_manager.zig");

pub var loaded = false;

pub const Entity = struct {
    id: u32,

    pub fn do_physics(self: Entity, dt: f32) void {
        const can_do_physics = storage.mask.items[self.id].velocity and storage.mask.items[self.id].aabb and storage.mask.items[self.id].transform and storage.mask.items[self.id].on_ground;
        if (!can_do_physics) return;

        const vel = self.get_ptr(.velocity);
        const on_ground_ptr = self.get_ptr(.on_ground);

        const max_move_per_step: f32 = 0.45 / @as(f32, c.SUB_BLOCKS_PER_BLOCK);

        const mx = @abs(vel[0]) * dt;
        const my = @abs(vel[1]) * dt;
        const mz = @abs(vel[2]) * dt;
        const max_disp = @max(mx, @max(my, mz));
        const step_f32 = max_disp / max_move_per_step;
        const steps_i32 = if (max_disp <= max_move_per_step) 1 else @as(i32, @intFromFloat(@ceil(step_f32)));
        const steps: i32 = @max(steps_i32, 1);
        const sub_dt: f32 = dt / @as(f32, @floatFromInt(steps));

        var i: i32 = 0;
        while (i < steps) : (i += 1) {
            var new_pos = [_]f32{
                self.get(.transform).pos[0] + vel[0] * sub_dt,
                self.get(.transform).pos[1] + vel[1] * sub_dt,
                self.get(.transform).pos[2] + vel[2] * sub_dt,
            };

            self.get(.aabb).collide_aabb_with_world(&new_pos, vel, on_ground_ptr);
            self.get_ptr(.transform).pos = new_pos;
        }
    }

    pub const MAX_ENTITY_DRAW_DISTANCE = 40.0; // Maximum distance to draw entities
    pub fn draw(self: Entity, shadow: bool, center: [3]f32) void {
        const can_draw = storage.mask.items[self.id].model and storage.mask.items[self.id].transform;
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
            var model = mm.get_model(self.get(.model));
            model.draw();
        } else {
            gfx.shader.use_render_shader();
            gfx.shader.set_model(self.get(.transform).get_matrix());
            var model = mm.get_model(self.get(.model));
            model.draw();
        }
    }

    pub fn get(entity: Entity, comptime comp_type: ComponentType) ComponentTypes[@intFromEnum(comp_type)] {
        return get_ptr(entity, comp_type).*;
    }

    pub fn get_ptr(entity: Entity, comptime comp_type: ComponentType) *ComponentTypes[@intFromEnum(comp_type)] {
        assert(initialized);
        // std.debug.print("ID: {}\n", .{entity.id});
        assert(entity.id < storage.transform.items.len);

        return &@field(storage, @tagName(comp_type)).items[entity.id];
    }

    pub fn add_component(entity: Entity, comptime comp_type: ComponentType, component: ComponentTypes[@intFromEnum(comp_type)]) !void {
        assert(initialized);
        assert(entity.id < storage.transform.items.len);

        const id = entity.id;

        @field(storage, @tagName(comp_type)).items[id] = component;
        @field(storage.mask.items[id], @tagName(comp_type)) = true;
    }
};

var initialized = false;

pub const EntityKind = enum(u8) {
    none = 0,
    player = 1,
    dragoon = 2,
    tomato = 3,
    dragoon_builder = 4,
    dragoon_farmer = 5,
    dragoon_lumberjack = 6,
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
    ai_state = 9,
    home_pos = 10,
    target_pos = 11,
    inventory = 12,
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
    usize,
    [3]isize,
    [3]isize,
    components.InventoryComponent,
};

pub const Mask = packed struct(u32) {
    kind: bool = true, // By default, all entities have a kind.
    transform: bool = false,
    model: bool = false,
    aabb: bool = false,
    velocity: bool = false,
    on_ground: bool = false,
    health: bool = false,
    timer: bool = false,
    ai_state: bool = false,
    home_pos: bool = false,
    target_pos: bool = false,
    inventory: bool = false,
    reserved: u20 = 0,
};

fn ecs_storage() type {
    var fields: [ComponentTypes.len + 1]std.builtin.Type.StructField = @splat(std.builtin.Type.StructField{
        .alignment = 1,
        .is_comptime = false,
        .name = "",
        .type = u0,
        .default_value_ptr = null,
    });

    for (std.meta.fields(ComponentType), 0..) |c_type, i| {
        fields[i] = std.builtin.Type.StructField{
            .alignment = 0,
            .is_comptime = false,
            .name = c_type.name,
            .type = std.ArrayListUnmanaged(ComponentTypes[c_type.value]),
            .default_value_ptr = null,
        };
    }

    fields[ComponentTypes.len] = std.builtin.Type.StructField{
        .alignment = 0,
        .is_comptime = false,
        .name = "active_entities",
        .type = std.ArrayListUnmanaged(Entity),
        .default_value_ptr = null,
    };

    const T: std.builtin.Type = std.builtin.Type{
        .@"struct" = .{
            .backing_integer = null,
            .is_tuple = false,
            .layout = .auto,
            .decls = &[_]std.builtin.Type.Declaration{},
            .fields = &fields,
        },
    };

    return @Type(T);
}

pub var storage: ecs_storage() = undefined;

pub fn save_entities() !void {
    assert(initialized);

    // Save the current state of the ECS
    const file = try std.fs.cwd().createFile("world/entities.dat", .{ .truncate = true });
    defer file.close();

    const writer = file.deprecatedWriter();
    try writer.writeInt(u64, storage.active_entities.items.len, .little);

    for (storage.active_entities.items) |e| {
        try writer.writeInt(u32, e.id, .little);
    }

    inline for (std.meta.fields(ComponentType)) |c_type| {
        const array = @field(storage, c_type.name);

        for (array.items) |item| {
            const type_info = @typeInfo(@TypeOf(item));

            switch (type_info) {
                .int => {
                    try writer.writeInt(@TypeOf(item), item, .little);
                },
                .bool => {
                    try writer.writeInt(u8, @intFromBool(item), .little);
                },
                .@"struct" => {
                    try writer.writeStruct(item);
                },
                .@"enum" => |e| {
                    try writer.writeInt(e.tag_type, @intFromEnum(item), .little);
                },
                .vector => |v| {
                    if (v.len == 3) {
                        try writer.writeInt(u32, @bitCast(item[0]), .little);
                        try writer.writeInt(u32, @bitCast(item[1]), .little);
                        try writer.writeInt(u32, @bitCast(item[2]), .little);
                    } else {
                        @compileError("Unsupported vector length for saving: " ++ v.len);
                    }
                },
                .array => |a| {
                    if (a.len == 3) {
                        if (a.child == f32) {
                            try writer.writeInt(u32, @bitCast(item[0]), .little);
                            try writer.writeInt(u32, @bitCast(item[1]), .little);
                            try writer.writeInt(u32, @bitCast(item[2]), .little);
                        } else if (a.child == isize) {
                            try writer.writeInt(u64, @bitCast(item[0]), .little);
                            try writer.writeInt(u64, @bitCast(item[1]), .little);
                            try writer.writeInt(u64, @bitCast(item[2]), .little);
                        } else {
                            @compileError("Unsupported array type for saving: " ++ @typeName(@TypeOf(item)));
                        }
                    } else {
                        @compileError("Unsupported array length for saving: " ++ a.len);
                    }
                },
                else => @compileError("Unsupported component type for saving: " ++ c_type.name),
            }
        }
    }
}

pub fn load_entities() !void {
    assert(initialized);

    const file = try std.fs.cwd().openFile("world/entities.dat", .{});
    defer file.close();

    const reader = file.deprecatedReader();
    const entity_count = try reader.readInt(u64, .little);

    try storage.active_entities.ensureTotalCapacity(util.allocator(), entity_count);
    for (0..entity_count) |_| {
        const id = try reader.readInt(u32, .little);
        storage.active_entities.appendAssumeCapacity(Entity{ .id = id });
        std.debug.print("Loaded entity with ID: {}\n", .{id});
    }

    inline for (std.meta.fields(ComponentType), 0..) |c_type, i| {
        var array = &@field(storage, c_type.name);
        try array.ensureTotalCapacity(util.allocator(), entity_count);
        for (0..entity_count) |_| {
            const item = ComponentTypes[i];
            const type_info = @typeInfo(item);

            switch (type_info) {
                .int => {
                    array.appendAssumeCapacity(try reader.readInt(item, .little));
                },
                .bool => {
                    array.appendAssumeCapacity(try reader.readInt(u8, .little) == 1);
                },
                .@"struct" => {
                    array.appendAssumeCapacity(try reader.readStruct(item));
                },

                .@"enum" => |e| {
                    array.appendAssumeCapacity(@enumFromInt(try reader.readInt(e.tag_type, .little)));
                },
                .vector => |v| {
                    if (v.len == 3) {
                        var x: item = undefined;
                        x[0] = @bitCast(try reader.readInt(u32, .little));
                        x[1] = @bitCast(try reader.readInt(u32, .little));
                        x[2] = @bitCast(try reader.readInt(u32, .little));

                        array.appendAssumeCapacity(x);
                    } else {
                        @compileError("Unsupported vector length for loading: " ++ v.len);
                    }
                },
                .array => |a| {
                    if (a.len == 3) {
                        var x: item = undefined;
                        if (a.child == f32) {
                            x[0] = @bitCast(try reader.readInt(u32, .little));
                            x[1] = @bitCast(try reader.readInt(u32, .little));
                            x[2] = @bitCast(try reader.readInt(u32, .little));

                            array.appendAssumeCapacity(x);
                        } else if (a.child == isize) {
                            x[0] = @bitCast(try reader.readInt(u64, .little));
                            x[1] = @bitCast(try reader.readInt(u64, .little));
                            x[2] = @bitCast(try reader.readInt(u64, .little));

                            array.appendAssumeCapacity(x);
                        } else {
                            @compileError("Unsupported array type for loading: " ++ @typeName(@TypeOf(item)));
                        }
                    } else {
                        @compileError("Unsupported array length for loading: " ++ a.len);
                    }
                },
                else => @compileLog("Unsupported component type for loading: ", @typeName(@TypeOf(item))),
            }
        }
    }

    loaded = true;
}

pub fn init() !void {
    assert(!initialized);

    inline for (std.meta.fields(ComponentType), 0..) |c_type, i| {
        @field(storage, c_type.name) = try std.ArrayListUnmanaged(ComponentTypes[i]).initCapacity(util.allocator(), 32);
    }
    storage.active_entities = try std.ArrayListUnmanaged(Entity).initCapacity(util.allocator(), 32);

    initialized = true;

    load_entities() catch |err| {
        std.debug.print("Failed to load entities: {}\n", .{err});
    };

    assert(initialized);
}

pub fn deinit() void {
    assert(initialized);

    save_entities() catch |err| {
        std.debug.print("Failed to save entities: {}\n", .{err});
    };

    inline for (std.meta.fields(ComponentType)) |c_type| {
        @field(storage, c_type.name).deinit(util.allocator());
    }
    storage.active_entities.deinit(util.allocator());
    initialized = false;
    assert(!initialized);
}

pub fn create_entity(kind: EntityKind) !Entity {
    assert(initialized);

    const id = @as(u32, @intCast(storage.transform.items.len));
    inline for (std.meta.fields(ComponentType)) |c_type| {
        try @field(storage, c_type.name).append(util.allocator(), undefined);
    }
    try storage.active_entities.append(util.allocator(), Entity{ .id = id });
    storage.kind.items[id] = kind;
    storage.mask.items[id] = Mask{ .kind = true }; // Kind is always set.

    return .{
        .id = id,
    };
}
