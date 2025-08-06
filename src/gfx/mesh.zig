const std = @import("std");
const gl = @import("gl.zig");
const util = @import("../core/util.zig");

pub const Instance = struct {
    vert: [3]f32,
    col: [4]u8,
};

pub const Vertex = struct {
    vert: [3]f32,
};

pub const Index = u32;

vbo: c_uint,
ebo: c_uint,
ibo: c_uint,
vao: c_uint,

vertices: std.ArrayListUnmanaged(Vertex),
instances: std.ArrayListUnmanaged(Instance),
indices: std.ArrayListUnmanaged(Index),

const Self = @This();

pub fn new() !Self {
    var res: Self = undefined;
    gl.genVertexArrays(1, &res.vao);
    gl.genBuffers(1, &res.vbo);
    gl.genBuffers(1, &res.ebo);
    gl.genBuffers(1, &res.ibo);

    res.vertices = try std.ArrayListUnmanaged(Vertex).initCapacity(util.allocator(), 32);
    res.instances = try std.ArrayListUnmanaged(Instance).initCapacity(util.allocator(), 32);
    res.indices = try std.ArrayListUnmanaged(Index).initCapacity(util.allocator(), 32);

    return res;
}

pub fn clear(self: *Self) void {
    self.vertices.clearAndFree(util.allocator());
    self.indices.clearAndFree(util.allocator());
    self.instances.clearAndFree(util.allocator());
}

pub fn deinit(self: *Self) void {
    self.vertices.deinit(util.allocator());
    self.indices.deinit(util.allocator());
    self.instances.deinit(util.allocator());

    gl.deleteBuffers(1, &self.vbo);
    gl.deleteBuffers(1, &self.ebo);
    gl.deleteBuffers(1, &self.ibo);

    gl.deleteVertexArrays(1, &self.vao);
}

pub fn update(self: *Self) void {
    gl.bindVertexArray(self.vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
    gl.bufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(Vertex) * self.vertices.items.len), self.vertices.items.ptr, gl.STATIC_DRAW);

    gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @ptrFromInt(0 + @offsetOf(Vertex, "vert")));
    gl.enableVertexAttribArray(0);

    gl.bindBuffer(gl.ARRAY_BUFFER, self.ibo);
    gl.bufferData(gl.ARRAY_BUFFER, @intCast(@sizeOf(Instance) * self.instances.items.len), self.instances.items.ptr, gl.STATIC_DRAW);

    gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, @sizeOf(Instance), @ptrFromInt(0 + @offsetOf(Instance, "vert")));
    gl.enableVertexAttribArray(1);
    gl.vertexAttribDivisor(1, 1);

    gl.vertexAttribPointer(2, 4, gl.UNSIGNED_BYTE, gl.FALSE, @sizeOf(Instance), @ptrFromInt(0 + @offsetOf(Instance, "col")));
    gl.enableVertexAttribArray(2);
    gl.vertexAttribDivisor(2, 1);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ebo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(Index) * self.indices.items.len), self.indices.items.ptr, gl.STATIC_DRAW);
}

pub fn draw(self: *Self) void {
    gl.bindVertexArray(self.vao);
    gl.drawElementsInstanced(gl.TRIANGLES, @intCast(self.indices.items.len), gl.UNSIGNED_INT, null, @intCast(self.instances.items.len));
}
