const Key = @import("raylib").KeyboardKey;

pub const Text = struct {
    // Register panels
    register_labels: i32 = 180,
    register_fields: i32 = 220,

    // Disassembly panel
    pc_address: i32 = 255,
    regular_address: i32 = 170,
    number_line: i32 = 100,
};

pub const Window = struct {
    init_width: i32 = 800,
    init_height: i32 = 600,
    min_width: i32 = 400,
    min_height: i32 = 600,

    resizable: bool = true,
};

pub const Layout = struct {
    // For the emulator screen
    min_screen_size: i32 = 300,
    font_size: i32 = 24,

    padding: f32 = 10.0,
};

pub const Input = struct {
    pause: Key = .space,
    keyboard_map: [16]Key,
};

pub const small_keyboard_input_defaults: Input = .{
    .keyboard_map = .{ .z, .x, .c, .v, .a, .s, .d, .f, .q, .w, .e, .r, .kp_1, .kp_2, .kp_3, .kp_4 },
};
