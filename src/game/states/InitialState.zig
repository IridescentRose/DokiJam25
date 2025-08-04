const std = @import("std");
const c = @import("../consts.zig");
const State = @import("../../core/State.zig");
const util = @import("../../core/util.zig");
const gfx = @import("../../gfx/gfx.zig");
const Self = @This();
const Chunk = @import("../chunk.zig");
const worldgen = @import("../worldgen.zig");
const Player = @import("../player.zig");

chunk: Chunk,
player: Player,

fn init(ctx: *anyopaque) anyerror!void {
    var self = util.ctx_to_self(Self, ctx);

    self.player = try Player.init();
    try self.player.register_input();

    self.chunk = try Chunk.new([_]f32{ 0, 0, 0 });
    self.chunk.transform.pos[0] = -4;
    self.chunk.transform.pos[1] = -4;
    self.chunk.transform.pos[2] = -4 - 6;
    worldgen.init(42);
    try worldgen.fill(&self.chunk, [_]u32{ 0, 0 });
}

fn deinit(ctx: *anyopaque) void {
    var self = util.ctx_to_self(Self, ctx);
    self.chunk.deinit();
    self.player.deinit();
}

fn update(ctx: *anyopaque) anyerror!void {
    var self = util.ctx_to_self(Self, ctx);
    try self.chunk.update();

    self.player.update();
}

fn draw(ctx: *anyopaque) anyerror!void {
    var self = util.ctx_to_self(Self, ctx);
    gfx.clear_color(0.8, 1.0, 0.8, 1);
    gfx.clear();

    self.player.draw();
    self.chunk.draw();
}

pub fn state(self: *Self) State {
    return .{ .ptr = self, .tab = .{
        .init = init,
        .deinit = deinit,
        .draw = draw,
        .update = update,
    } };
}
