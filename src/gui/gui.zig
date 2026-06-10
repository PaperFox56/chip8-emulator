//!
//! display.zig
//!
//! Defines the GUI interface allowing to interact with

const std = @import("std");

const chip8 = @import("chemuz8_core").chip8;
const debug = @import("chemuz8_core").debugger;
const rl = @import("raylib");
const rgui = @import("raygui");

const nfd = @import("nfd");

const gui_manager = @import("gui_manager.zig");
const GuiState = gui_manager.GuiState;
const TextBoxManager = gui_manager.TextBoxManager;
const RegisterMap = gui_manager.RegisterMap;
const ceilDiv = gui_manager.ceilDiv;

const GuiError = error{
    ScreenTexture,
    Font,
};

// For drawing
//---------
const BLACK = 0;
const DARK_GRAY = 100;
const GRAY = 200;
const WHITE = 255;

const text_colors = .{
    // Register panels
    .register_labels = 180,
    .register_fields = 220,

    // Disassembly panel
    .pc_address = 255,
    .regular_address = 170,
    .number_line = 100,
};

const window_configs = .{
    .init_width = 800,
    .init_height = 600,
    .min_width = 400,
    .min_height = 600,
    .resizable = true,
};

const panel_configs = .{
    // For the emulator screen
    .min_screen_size = 300,
    .padding = 10.0,
    .font_size = 24,
};

comptime {
    if (window_configs.init_width < window_configs.min_width or
        window_configs.init_height < window_configs.min_height)
    {
        @compileError(
            \\Window configs validation failed:
            \\Initial size cannot be smaller than min size!
        );
    }
}
//----------

pub fn run(io: std.Io, debugger: *debug.Debugger) GuiError!void {

    // Initialization
    //--------------------------------------------------------------------------------------
    initGUI();
    defer rl.closeWindow(); // Close window and OpenGL context

    var gui_state = GuiState{
        .window_width = @intCast(rl.getScreenWidth()),
        .window_height = @intCast(rl.getScreenHeight()),
    };
    TextBoxManager.build_many(gui_state.V[0..]);
    TextBoxManager.build_many(gui_state.specials[0..]);
    TextBoxManager.build_many(gui_state.timers[0..]);

    // This array will be ussed to draw the chip8's screen
    var screen_pixels: [chip8.screen.pixel_count]u8 = @splat(BLACK);

    const screen_texture = create_screen_texture(&screen_pixels) orelse {
        std.debug.print("gui.run: The GUI couldn't be initialized", .{});
        return GuiError.ScreenTexture;
    };
    defer rl.unloadTexture(screen_texture);

    const my_font = rl.loadFontEx("fonts/tahoma.ttf", panel_configs.font_size, null) catch return GuiError.Font;
    defer rl.unloadFont(my_font);

    rgui.setFont(my_font);

    // Timing
    const target_time_per_frame_ns = 1_000_000_000 / 60;
    var last_frame = std.Io.Clock.awake.now(io).nanoseconds;
    //--------------------------------------------------------------------------------------

    var instr_count: u32 = 0;

    debugger.emulation_speed = 1;
    debugger.init(@intCast(last_frame));

    // Main game loop
    while (true) { // Detect window close button or ESC key

        const current_time_ns = std.Io.Clock.awake.now(io).nanoseconds;
        const delta = current_time_ns - last_frame;

        if (debugger.update(@intCast(current_time_ns)))
            instr_count += 1;

        if (delta < target_time_per_frame_ns) {
            continue;
        }

        if (rl.windowShouldClose()) {
            break;
        }
        // Update
        //----------------------------------------------------------------------------------
        // File the screen texture with the content of the chip8 framebuffer

        for (0..chip8.screen.pixel_count) |i| {
            const row = i / chip8.screen.width;
            const col = i % chip8.screen.width;

            const shift_offset: u6 = @intCast(chip8.screen.width - col - 1);

            const pixel: u1 = @truncate(debugger.machine.framebuffer[row] >> shift_offset);
            screen_pixels[i] = switch (pixel) {
                1 => if (debugger.paused) GRAY else WHITE,
                0 => if (debugger.paused) DARK_GRAY else BLACK,
            };
        }

        // Push the mutated local memory array safely across the PCIe bus pipeline
        rl.updateTexture(screen_texture, &screen_pixels);
        //----------------------------------------------------------------------------------

        // Input
        // --------------------------------------------
        if (rl.isKeyPressed(.space)) {
            if (!gui_state.pause_key_pressed) {
                gui_state.pause_key_pressed = true;

                debugger.paused = !debugger.paused;
            }
        } else {
            gui_state.pause_key_pressed = false;
        }
        // --------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------

        const IPS = instr_count * 60;
        std.debug.print("IPS: {}, FPS: {}\n", .{ IPS, @divTrunc(1_000_000_000, delta) });
        instr_count = 0;

        last_frame = current_time_ns;

        // Get the window's size in case it was rescaled
        gui_state.window_width = @intCast(rl.getScreenWidth());
        gui_state.window_height = @intCast(rl.getScreenHeight());

        gui_state.tab_mode = gui_state.window_width < panel_configs.min_screen_size * 2;

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.white);

        draw(&gui_state, screen_texture, debugger, io);

        //----------------------------------------------------------------------------------
    }
}
// Generate the labels for the general registers at comptime
pub const register_names = blk: {
    var temp_names: [16][:0]const u8 = undefined;

    for (0..16) |i| {
        // Construct the string at compile time.
        // Adding the \x00 ensures it is a valid sentinel-terminated C-string slice.
        temp_names[i] = "V" ++ std.fmt.comptimePrint("{X}\x00", .{i});
    }

    break :blk temp_names;
};

fn draw(state: *GuiState, screen_texture: rl.Texture, debugger: *debug.Debugger, io: std.Io) void {
    var total_needed_height: f32 = 0.0;

    // Screen
    //--------------------------
    // In tab mode, the screen takes up all of the window's width
    const panel_size: f32 = @floatFromInt(
        if (state.tab_mode)
            state.window_width
        else
            state.window_width / 2,
    );
    const screen_rect = rl.Rectangle{
        .x = @as(f32, @floatFromInt(state.window_width)) - panel_size + panel_configs.padding,
        .y = panel_configs.padding,
        .width = panel_size - panel_configs.padding * 2,
        .height = panel_size / 2 - panel_configs.padding * 2,
    };

    // Render the texture
    rl.drawTexturePro(
        screen_texture,
        rl.Rectangle{ .x = 0, .y = 0, .width = chip8.screen.width, .height = chip8.screen.height },
        screen_rect,
        rl.Vector2{ .x = 0, .y = 0 }, // Origin anchor rotation offset
        0.0, // Angle rotation
        rl.Color.white, // Color tint multiplier modification
    );
    //--------------------------

    // Registers panel
    //--------------------------

    var panel_rect = rl.Rectangle{
        .x = screen_rect.x,
        .y = screen_rect.height + panel_configs.padding * 2,
        .width = screen_rect.width,
        .height = 0.0,
    };

    var generalRegisters: [16]RegisterMap = undefined;

    for (0..16) |i| {
        generalRegisters[i] = RegisterMap{
            .name = register_names[i],
            .val_ptr = &debugger.machine.V[i],
            .manager = &state.V[i],
        };
    }
    panel_rect.height = drawRegisterPanel(
        u8,
        panel_rect,
        "GENERAL REGISTERS",
        generalRegisters[0..],
        panel_configs.padding,
    );

    total_needed_height = panel_rect.height + panel_rect.y;
    panel_rect.y = total_needed_height + panel_configs.padding;

    panel_rect.height = drawRegisterPanel(
        u12,
        panel_rect,
        "SPECIAL REGISTERS",
        ([_]RegisterMap{
            RegisterMap{ .name = "PC", .val_ptr = &debugger.machine.PC, .manager = &state.specials[0] },
            RegisterMap{ .name = "I", .val_ptr = &debugger.machine.I, .manager = &state.specials[2] },
        })[0..],
        panel_configs.padding * 2,
    );

    total_needed_height = panel_rect.height + panel_rect.y;
    panel_rect.y = total_needed_height + panel_configs.padding;

    panel_rect.height = drawRegisterPanel(
        u8,
        panel_rect,
        "MISC",
        ([_]RegisterMap{
            RegisterMap{ .name = "SP", .val_ptr = &debugger.machine.SP, .manager = &state.specials[1] },
            RegisterMap{ .name = "DT", .val_ptr = &debugger.machine.DT, .manager = &state.timers[0] },
            RegisterMap{ .name = "ST", .val_ptr = &debugger.machine.ST, .manager = &state.timers[1] },
        })[0..],
        panel_configs.padding * 2,
    );

    total_needed_height = panel_rect.height + panel_rect.y + panel_configs.padding;

    // Let's make sure that the PC stays a multiple of two
    if (debugger.machine.PC % 2 == 1) debugger.machine.PC -= 1;

    //--------------------------

    // Disassembly panel
    //--------------------------
    if (!state.tab_mode) {
        panel_rect = .{
            .x = panel_configs.padding,
            .y = panel_configs.padding,
            .width = screen_rect.width,
            .height = total_needed_height - panel_configs.padding * 2,
        };

        _ = rgui.panel(panel_rect, "DISASSEMBLY");

        const line_height = 20.0;

        const padding = 5.0;
        const offset = 30.0;

        const count: usize = @intFromFloat((panel_rect.height - offset) / (line_height + padding));
        const pc_address = debugger.machine.PC;
        const byte_span = count * 2;

        const start_address = blk: {
            var val: usize = 0;

            if (pc_address + byte_span >= chip8.ram_size) {
                val = chip8.ram_size - byte_span;
            } else {
                const half_span = byte_span / 2;
                val = pc_address -| half_span;
            }

            if (val % 2 == 1) val += 1;

            break :blk val;
        };

        for (0..count) |i| {
            const y = @as(f32, @floatFromInt(i));
            const address = start_address + i * 2;

            var rect = rl.Rectangle{
                .x = panel_rect.x + panel_configs.padding,
                .y = panel_rect.y + offset + y * (line_height + padding),
                .width = 200,
                .height = line_height,
            };

            if (address == pc_address) {
                // Let's make this one shine a bit
                rl.drawRectangle(
                    @intFromFloat(panel_rect.x),
                    @intFromFloat(rect.y),
                    @intFromFloat(panel_rect.width),
                    @intFromFloat(line_height),
                    rl.Color.init(255, 109, 194, 150),
                );
            }

            const op = (@as(u16, debugger.machine.ram[address]) << 8) + debugger.machine.ram[address + 1];

            var buffer: [32]u8 = @splat(0);
            rgui.setStyle(.default, .{ .control = .text_color_normal }, text_colors.number_line);
            _ = rgui.label(
                rect,
                @ptrCast(std.fmt.bufPrint(buffer[0..], "{X:03}", .{address}) catch "???\x00"),
            );

            rect.x += 60.0;
            if (address == pc_address) {
                rgui.setStyle(.default, .{ .control = .text_color_normal }, text_colors.pc_address);
            } else {
                rgui.setStyle(.default, .{ .control = .text_color_normal }, text_colors.regular_address);
            }
            buffer = @splat(0);
            _ = rgui.label(rect, debug.disassemble(buffer[0..], op));
        }
    }

    //--------------------------

    // Controls
    //--------------------------
    const control_height = 30.0;

    if (rgui.button(
        .{
            .x = panel_configs.padding,
            .y = total_needed_height,
            .width = 100.0,
            .height = control_height,
        },
        "Load ROM",
    )) {
        // TODO: properly handle the errors
        if (nfd.openFileDialog("ch8", null) catch null) |path| {
            // Defer freeing the memory string handled by the native C library
            defer nfd.freePath(path);

            std.debug.print("User selected ROM file path: {s}\n", .{path});

            debugger.load_ROM(io, path) catch unreachable;
        } else {
            // The user closed the window or clicked the "Cancel" option button
            std.debug.print("User cancelled file selection.\n", .{});
        }
    }

    total_needed_height += control_height + panel_configs.padding;
    // now let's make sure that the window is big enough for everything to fit
    rl.setWindowSize(@intCast(state.window_width), @intFromFloat(total_needed_height));
    //--------------------------
}

pub fn drawRegisterPanel(
    comptime reg_type: type,
    rect: rl.Rectangle,
    title: [:0]const u8,
    registers: []const RegisterMap,
    padding: f32,
) f32 {
    const digit_count = ceilDiv(comptime_int, @bitSizeOf(reg_type), 4);
    const digit_count_f32: f32 = @floatFromInt(digit_count);
    const slot_height: f32 = 30.0;
    const label_size = @as(f32, @floatFromInt(rgui.getTextWidth("0,")));
    const slot_width = label_size * (2.0 + digit_count_f32) + padding;

    // We don't want this value to be 0
    const slots_per_line = @max(1.0, @divFloor(rect.width - panel_configs.padding, slot_width));
    const final_slot_width = rect.width / slots_per_line;
    const cols = @ceil(@as(f32, @floatFromInt(registers.len)) / slots_per_line);

    var _rect = rect;
    _rect.height = (cols + 0.75) * (slot_height + padding);

    // Render the container panel with centered alignment
    rgui.setStyle(.default, .{ .control = .text_alignment }, @intFromEnum(rgui.TextAlignment.center));
    _ = rgui.panel(_rect, title);
    rgui.setStyle(.default, .{ .control = .text_alignment }, @intFromEnum(rgui.TextAlignment.left));

    const panel_border = 30.0;

    // Display the registers in a grid
    for (registers, 0..) |reg, i| {
        const i_f32 = @as(f32, @floatFromInt(i));
        const x = @mod(i_f32, slots_per_line);
        const y = @divFloor(i_f32, slots_per_line);

        var slot_rect = rl.Rectangle{
            .x = rect.x + padding + x * final_slot_width,
            .y = rect.y + panel_border + y * (slot_height + padding),
            .width = label_size * 2.0,
            .height = slot_height,
        };

        rgui.setStyle(.label, .{ .control = .text_color_normal }, text_colors.register_labels);
        _ = rgui.label(slot_rect, @ptrCast(reg.name));

        // Push layout boundaries over for the input field text box
        slot_rect.x += slot_rect.width;
        slot_rect.width = label_size * digit_count_f32 + 5.0;

        if (!reg.manager.edit_mode) {
            // Perform type-safe unpackings based on the type
            switch (reg_type) {
                u8, u12, u16 => |t| reg.manager.fillFromInt(t, @as(*t, @ptrCast(@alignCast(reg.val_ptr))).*),
                else => unreachable,
            }
        }

        // Render textbox
        const temp: [:0]u8 = @ptrCast(reg.manager.buffer[0..digit_count]);
        rgui.setStyle(.textbox, .{ .control = .text_color_normal }, text_colors.register_fields);
        if (rgui.textBox(slot_rect, temp, reg.manager.edit_mode)) {
            reg.manager.edit_mode = !reg.manager.edit_mode;

            // Update the register
            if (!reg.manager.edit_mode) {
                switch (reg_type) {
                    u8, u12, u16 => |t| if (reg.manager.getIntValue(t)) |v| {
                        @as(*t, @ptrCast(@alignCast(reg.val_ptr))).* = v;
                    },
                    else => unreachable,
                }
            }
        }
    }

    return _rect.height;
}

fn initGUI() void {
    const windowWidth = 800;
    const windowHeight = 600;

    // Mkae the window resizable
    const flags = rl.ConfigFlags{
        .window_resizable = window_configs.resizable,
        .vsync_hint = true,
    };
    rl.setConfigFlags(flags);
    rl.initWindow(windowWidth, windowHeight, "Chemuz8");

    rl.setWindowMinSize(window_configs.min_width, window_configs.min_height);

    // Set global styles

    rgui.setStyle(
        .default,
        .{ .default = .text_size },
        panel_configs.font_size,
    );
}

fn create_screen_texture(screen_pixels: [*]u8) ?rl.Texture {
    // Construct metadata structure pointing to the dimensions
    const img = rl.Image{
        .data = screen_pixels,
        .width = chip8.screen.width,
        .height = chip8.screen.height,
        .mipmaps = 1,
        .format = .uncompressed_grayscale,
    };

    // Push memory block into GPU VRAM
    const texture = rl.loadTextureFromImage(img) catch {
        std.debug.print("create_screen_texture: Couldn't create a texture", .{});
        return null;
    };

    // CRITICAL: Set nearest-neighbor filtering to maintain pixelated scaling textures
    rl.setTextureFilter(texture, .point);

    return texture;
}
