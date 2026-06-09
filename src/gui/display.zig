//!
//! display.zig
//!
//! Defines the GUI interface allowing to interact with

const std = @import("std");

const chip8 = @import("chemuz8_core").chip8;
const debug = @import("chemuz8_core").debugger;
const rl = @import("raylib");
const rgui = @import("raygui");

const GuiState = @import("gui_manager.zig").GuiState;
const TextBoxManager = @import("gui_manager.zig").TextBoxManager;

const GuiError = error{
    ScreenTexture,
};

// For drawing
//---------
const BLACK = 0;
const DARK_GRAY = 100;
const GRAY = 200;
const WHITE = 255;

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

    // This array will be ussed to draw the chip8's screen
    var screen_pixels: [chip8.screen.pixel_count]u8 = @splat(BLACK);

    const screen_texture = create_screen_texture(&screen_pixels) orelse {
        std.debug.print("gui.run: The GUI couldn't be initialized", .{});
        return GuiError.ScreenTexture;
    };
    defer rl.unloadTexture(screen_texture);

    const target_time_per_frame_ns = 1_000_000_000 / 60;
    var last_frame = std.Io.Clock.awake.now(io).nanoseconds;

    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
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

        const current_time_ns = std.Io.Clock.awake.now(io).nanoseconds;

        if (current_time_ns - last_frame >= target_time_per_frame_ns) {
            last_frame = current_time_ns;

            // Get the window's size in case it was rescaled
            gui_state.window_width = @intCast(rl.getScreenWidth());
            gui_state.window_height = @intCast(rl.getScreenHeight());

            gui_state.tab_mode = gui_state.window_width < panel_configs.min_screen_size * 2;

            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(.white);
            debugger.update();

            draw(&gui_state, screen_texture, debugger);
        }

        //----------------------------------------------------------------------------------
    }
}

fn draw(state: *GuiState, screen_texture: rl.Texture, debugger: *debug.Debugger) void {
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

    // We need to do some calculations for the layout of the registers
    const label_size: f32 = @floatFromInt(rgui.getTextWidth("000")); // just an estimate
    var slot_width = label_size * 2 + panel_configs.padding;
    const slot_height = 30.0;

    const slot_per_line: f32 = @max(1.0, @divFloor(screen_rect.width, slot_width));
    const cols = @ceil(16.0 / slot_per_line);

    const panel_rect = rl.Rectangle{
        .x = screen_rect.x,
        .y = screen_rect.height + panel_configs.padding * 2,
        .width = screen_rect.width,
        .height = (cols + 2.5) * slot_height,
    };

    rgui.setStyle(
        .default,
        .{ .control = .text_alignment },
        @intFromEnum(rgui.TextAlignment.center),
    );
    _ = rgui.panel(panel_rect, "GENERAL REGISTER PANEL");

    // Go back to normal aligment
    rgui.setStyle(
        .default,
        .{ .control = .text_alignment },
        @intFromEnum(rgui.TextAlignment.left),
    );

    // Take up all of the horizontal space
    slot_width = panel_rect.width / slot_per_line;

    for (0..16) |i| {
        const i_f32: f32 = @floatFromInt(i);
        const x = @mod(i_f32, slot_per_line);
        const y = @divFloor(i_f32, slot_per_line);

        const manager = &state.V[i];

        var rect = rl.Rectangle{
            .x = panel_rect.x + panel_configs.padding + x * slot_width,
            .y = panel_rect.y + panel_configs.padding * 3 + y * (slot_height + panel_configs.padding),
            .width = label_size,
            .height = 30,
        };
        var buf: [8:0]u8 = undefined;
        // We want to show all of the general purpose registers
        const label = std.fmt.bufPrint(&buf, "V{X}\x00", .{i}) catch "??\x00";
        _ = rgui.label(rect, @ptrCast(label));
        rect.x += label_size;
        rect.width += 5.0;

        // we only need 2 characters
        const temp: [:0]u8 = @ptrCast(manager.buffer[0..2]);
        if (rgui.textBox(rect, temp, manager.edit_mode)) {
            if (manager.getIntValue(u8)) |value| {
                debugger.machine.V[i] = value;
            }
            manager.edit_mode = !manager.edit_mode;
        }
        if (!manager.edit_mode) {
            manager.fillFromInt(u8, debugger.machine.V[i]);
        }
    }
    //--------------------------
}

fn initGUI() void {
    const windowWidth = 800;
    const windowHeight = 600;

    // Mkae the window resizable
    const flags = rl.ConfigFlags{
        .window_resizable = window_configs.resizable,
    };
    rl.setConfigFlags(flags);
    rl.initWindow(windowWidth, windowHeight, "Chemuz8");

    rl.setWindowMinSize(window_configs.min_width, window_configs.min_height);

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    // Set global styles

    rgui.setStyle(
        .label,
        .{ .control = .text_color_normal },
        DARK_GRAY,
    );

    rgui.setStyle(
        .default,
        .{ .default = .text_size },
        24,
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
