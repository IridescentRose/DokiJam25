const BuildingKind = enum(u8) {
    TownHall = 0,
    House = 1,
    Farm = 2,
    Path = 3,
    Fence = 4,
};

kind: BuildingKind,
position: [3]isize,
is_built: bool,
progress: usize = 0,
