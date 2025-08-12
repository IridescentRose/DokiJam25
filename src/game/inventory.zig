const std = @import("std");
const Chunk = @import("chunk.zig");
const Self = @This();

pub const Slot = struct {
    material: u16,
    count: u16,
};

pub const MAX_ITEMS_PER_SLOT = 64000; // Rounds nicely to 1000 voxels of 64 items each
pub const MAX_SLOTS = 32;
pub const HOTBAR_SIZE = 8;

hotbarIdx: u8 = 0,
slots: [MAX_SLOTS]Slot = @splat(.{ .material = 0, .count = 0 }),
mouse_slot: Slot = .{ .material = 0, .count = 0 },

pub fn new() Self {
    return Self{};
}

pub fn get_hand_slot(self: *Self) *Slot {
    return &self.slots[self.hotbarIdx];
}

pub fn increment_hotbar(self: *Self) void {
    self.hotbarIdx = @min(HOTBAR_SIZE - 1, (self.hotbarIdx + 1) % HOTBAR_SIZE);
}

pub fn decrement_hotbar(self: *Self) void {
    self.hotbarIdx -|= 1;
}

pub fn remove_item_hand(self: *Self) bool {
    const slot = self.get_hand_slot();

    if (slot.material == 0) return false;
    if (slot.count == 0) return false;

    return true;
}

// Tries to add an item to the inventory, returns back how many items were added
pub fn add_item_inventory(self: *Self, to_add: Slot) usize {
    var total_added: usize = 0;
    for (0..MAX_SLOTS) |i| {
        if (total_added == to_add.count) break;

        if (self.slots[i].material == to_add.material) {
            const added = @min(to_add.count, MAX_ITEMS_PER_SLOT -| self.slots[i].count);
            self.slots[i].count += added;

            total_added += added;
        }

        if (self.slots[i].material == 0) {
            const added = @min(to_add.count - total_added, MAX_ITEMS_PER_SLOT);
            self.slots[i].material = to_add.material;
            self.slots[i].count = added;

            total_added += added;
        }
    }
    return total_added;
}
