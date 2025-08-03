const std = @import("std");
const gl = @import("gl.zig");
const util = @import("../core/util.zig");

pub const Vertex = extern struct {
    vert: [3]f32,
    col: [4]u8,
    tex: [2]f32,
    norm: [3]f32,
};

pub const Index = u32;

vbo: c_uint,
ebo: c_uint,
vao: c_uint,

vertices: std.ArrayListUnmanaged(Vertex),
indices: std.ArrayListUnmanaged(Index),

const Self = @This();

pub fn new() !Self {
    var res: Self = undefined;
    gl.genVertexArrays(1, &res.vao);
    gl.genBuffers(1, &res.vbo);
    gl.genBuffers(1, &res.ebo);

    res.vertices = try std.ArrayListUnmanaged(Vertex).initCapacity(util.allocator(), 32);
    res.indices = try std.ArrayListUnmanaged(Index).initCapacity(util.allocator(), 32);

    return res;
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
    gl.vertexAttribPointer(1, 4, gl.UNSIGNED_BYTE, gl.TRUE, @sizeOf(Vertex), @ptrFromInt(0 + @offsetOf(Vertex, "col")));
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @ptrFromInt(0 + @offsetOf(Vertex, "tex")));
    gl.enableVertexAttribArray(2);
    gl.vertexAttribPointer(3, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), @ptrFromInt(0 + @offsetOf(Vertex, "norm")));
    gl.enableVertexAttribArray(3);

    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ebo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(@sizeOf(Index) * self.indices.items.len), self.indices.items.ptr, gl.STATIC_DRAW);
}

pub fn draw(self: *Self) void {
    gl.bindVertexArray(self.vao);
    gl.drawElements(gl.TRIANGLES, @intCast(self.indices.items.len), gl.UNSIGNED_INT, null);
}
