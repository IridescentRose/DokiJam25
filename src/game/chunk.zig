const c = @import("consts.zig");

pub const AtomKind = enum(u8) {
    Air,
    Dirt,
    Stone,
    Water,
};

pub const Atom = struct {
    material: AtomKind,
    color: [3]u8,

    comptime {
        if (@sizeOf(Atom) != 4) {
            @compileError("Atom struct size must be 4 bytes");
        }
    }
};

offset: usize,
size: usize = c.CHUNK_SUBVOXEL_SIZE,

pub fn get_index(coord: [3]usize) usize {
    return (coord[1] * c.CHUNK_SUB_BLOCKS + coord[2]) * c.CHUNK_SUB_BLOCKS + coord[0];
}
