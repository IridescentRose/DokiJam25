const gfx = @import("../gfx/gfx.zig");
const Voxel = @import("voxel.zig");

pub const ModelID = enum(u32) {
    Player = 0,
    Farmer = 1,
    Builder = 2,
    Lumberjack = 3,
    Sleep = 4,
    Mint = 5,
    Dooby = 6,
    Nimi = 7,
    Chibi = 8,
    Tomato = 9,
};

var player_model: Voxel = undefined;
var farmer_model: Voxel = undefined;
var builder_model: Voxel = undefined;
var lumber_model: Voxel = undefined;
var sleep_model: Voxel = undefined;

var mint_model: Voxel = undefined;
var dooby_model: Voxel = undefined;
var nimi_model: Voxel = undefined;
var chibi_model: Voxel = undefined;
var tomato_model: Voxel = undefined;

pub fn init() !void {
    const farmer_tex = try gfx.texture.load_image_from_file("assets/model/dragoon_farmer.png");
    farmer_model = Voxel.init(farmer_tex);
    try farmer_model.build();

    const builder_tex = try gfx.texture.load_image_from_file("assets/model/dragoon_builder.png");
    builder_model = Voxel.init(builder_tex);
    try builder_model.build();

    const lumber_tex = try gfx.texture.load_image_from_file("assets/model/dragoon_lumber.png");
    lumber_model = Voxel.init(lumber_tex);
    try lumber_model.build();

    const sleep_tex = try gfx.texture.load_image_from_file("assets/model/dragoon_sleep.png");
    sleep_model = Voxel.init(sleep_tex);
    try sleep_model.build();

    const player_tex = try gfx.texture.load_image_from_file("assets/model/doki.png");
    player_model = Voxel.init(player_tex);
    try player_model.build();

    mint_model = Voxel.init(try gfx.texture.load_image_from_file("assets/model/mint.png"));
    try mint_model.build();

    dooby_model = Voxel.init(try gfx.texture.load_image_from_file("assets/model/dooby.png"));
    try dooby_model.build();

    nimi_model = Voxel.init(try gfx.texture.load_image_from_file("assets/model/nimi.png"));
    try nimi_model.build();

    chibi_model = Voxel.init(try gfx.texture.load_image_from_file("assets/model/chibi.png"));
    try chibi_model.build();

    tomato_model = Voxel.init(try gfx.texture.load_image_from_file("assets/model/tomato.png"));
    try tomato_model.build();
}

pub fn get_model(id: ModelID) *Voxel {
    switch (id) {
        .Player => return &player_model,
        .Farmer => return &farmer_model,
        .Builder => return &builder_model,
        .Lumberjack => return &lumber_model,
        .Sleep => return &sleep_model,
        .Mint => return &mint_model,
        .Dooby => return &dooby_model,
        .Nimi => return &nimi_model,
        .Chibi => return &chibi_model,
        .Tomato => return &tomato_model,
    }
}

pub fn deinit() void {
    farmer_model.deinit();
    builder_model.deinit();
    lumber_model.deinit();
    sleep_model.deinit();
    player_model.deinit();
    mint_model.deinit();
    dooby_model.deinit();
    nimi_model.deinit();
    chibi_model.deinit();
    tomato_model.deinit();
}
