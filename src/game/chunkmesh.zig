const std = @import("std");
const gl = @import("../gfx/gl.zig");
const util = @import("../core/util.zig");
const c = @import("consts.zig");
const shader = @import("../gfx/shaders.zig");
const world = @import("world.zig");
const zm = @import("zmath");

pub const Vertex = struct {
    vert: [3]f32,
};

pub const Index = u32;

vbo: c_uint,
ebo: c_uint,
ssbo: c_uint,
vao: c_uint,

vertices: std.ArrayListUnmanaged(Vertex),
indices: std.ArrayListUnmanaged(Index),

const Self = @This();

pub fn new() !Self {
    var res: Self = undefined;
    gl.genVertexArrays(1, &res.vao);
    gl.genBuffers(1, &res.vbo);
    gl.genBuffers(1, &res.ebo);
    gl.genBuffers(1, &res.ssbo);

    res.vertices = try std.ArrayListUnmanaged(Vertex).initCapacity(util.allocator(), 32);
    res.indices = try std.ArrayListUnmanaged(Index).initCapacity(util.allocator(), 32);

    gl.bindVertexArray(res.vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, res.vbo);
    gl.bufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(Vertex) * res.vertices.items.len), res.vertices.items.ptr, gl.STATIC_DRAW);

    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @ptrFromInt(0 + @offsetOf(Vertex, "vert")));
    gl.enableVertexAttribArray(0);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, res.ebo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(Index) * res.indices.items.len), res.indices.items.ptr, gl.STATIC_DRAW);

    // Pre-allocate the ssbo for chunk data
    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, res.ssbo);
    gl.bufferData(gl.SHADER_STORAGE_BUFFER, @intCast(@sizeOf(u32) * c.CHUNK_SUBVOXEL_SIZE), null, gl.DYNAMIC_DRAW);
    gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, res.ssbo);

    return res;
}

pub fn clear(self: *Self) void {
    self.vertices.clearAndFree(util.allocator());
    self.indices.clearAndFree(util.allocator());
}

pub fn deinit(self: *Self) void {
    self.vertices.deinit(util.allocator());
    self.indices.deinit(util.allocator());

    gl.deleteBuffers(1, &self.vbo);
    gl.deleteBuffers(1, &self.ebo);

    gl.deleteVertexArrays(1, &self.vao);
}

pub fn update(self: *Self) void {
    gl.bindVertexArray(self.vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
    gl.bufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(Vertex) * self.vertices.items.len), self.vertices.items.ptr, gl.STATIC_DRAW);

    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @ptrFromInt(0 + @offsetOf(Vertex, "vert")));
    gl.enableVertexAttribArray(0);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ebo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(Index) * self.indices.items.len), self.indices.items.ptr, gl.STATIC_DRAW);
}

pub fn update_chunk_data(self: *Self, data: []u32) void {
    gl.bindVertexArray(self.vao);
    gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, self.ssbo);

    // Orphan the buffer to avoid stalls
    gl.bufferData(gl.SHADER_STORAGE_BUFFER, @intCast(@sizeOf(u32) * c.CHUNK_SUBVOXEL_SIZE), null, gl.DYNAMIC_DRAW);
    gl.bufferSubData(gl.SHADER_STORAGE_BUFFER, 0, @intCast(data.len * @sizeOf(u32)), data.ptr);

    // std.debug.print("Updated {} bytes of chunk data\n", .{data.len * @sizeOf(u32)});
}

pub fn draw(self: *Self) void {
    shader.use_ray_shader();
    shader.set_ray_resolution();
    shader.set_ray_vp(world.player.camera.get_projview_matrix());
    shader.set_ray_inv_vp(zm.inverse(world.player.camera.get_projview_matrix()));

    gl.bindVertexArray(self.vao);
    gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, self.ssbo);

    gl.drawElements(gl.TRIANGLES, @intCast(self.indices.items.len), gl.UNSIGNED_INT, null);
}
