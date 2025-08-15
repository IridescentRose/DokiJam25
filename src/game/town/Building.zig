const BuildingKind = enum {
    House,
    TownHall,
    Farm,
    Path,
    Fence,
};

kind: BuildingKind,
position: [3]isize,
size: [3]isize,
is_built: bool,
