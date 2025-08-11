ptr: *anyopaque,
tab: VTable,

const VTable = struct {
    init: *const fn (ctx: *anyopaque) anyerror!void,
    deinit: *const fn (ctx: *anyopaque) void,

    update: *const fn (ctx: *anyopaque) anyerror!void,
    draw: *const fn (ctx: *anyopaque, shadow: bool) anyerror!void,
};

const Self = @This();

pub fn init(self: *Self) anyerror!void {
    try self.tab.init(self.ptr);
}

pub fn deinit(self: *Self) void {
    self.tab.deinit(self.ptr);
}

pub fn update(self: *Self) anyerror!void {
    try self.tab.update(self.ptr);
}

pub fn draw(self: *Self, shadow: bool) anyerror!void {
    try self.tab.draw(self.ptr, shadow);
}
