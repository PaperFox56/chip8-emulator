//!
//! display.zig
//!
//! Defines the GUI interface allowing to interact with

const std = @import("std");

const chip8 = @import("chemuz8_core").chip8;
const rl = @import("raylib");
const rgui = @import("raygui");

const GuiError = error{
    ScreenTexture,
};

// For drawing
//---------
const BLACK = 0;
const WHITE = 255;

const window_configs = .{
    .init_width = 800,
    .init_height = 600,
    .min_width = 500,
    .min_height = 600,
    .resizable = true,
};

const panel_configs = .{
    // For the emulator screen
    .min_screen_size = 300,
    .padding = 10.0,
};

const GuiState = struct {
    window_width: u32,
    window_height: u32,

    tab_mode: bool = false,
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

pub fn run(machine: *chip8.Chip8) GuiError!void {

    // Initialization
    //--------------------------------------------------------------------------------------
    initGUI();
    defer rl.closeWindow(); // Close window and OpenGL context

    var gui_state: GuiState = undefined;

    // This array will be ussed to draw the chip8's screen
    var screen_pixels: [chip8.screen.pixel_count]u8 = @splat(BLACK);

    const screen_texture = create_screen_texture(&screen_pixels) orelse {
        std.debug.print("gui.run: The GUI couldn't be initialized", .{});
        return GuiError.ScreenTexture;
    };
    defer rl.unloadTexture(screen_texture);

    //--------------------------------------------------------------------------------------

    //var color = rl.Color.red;
    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // File the screen texture with the content of the chip8 framebuffer
        machine.step_through();

        for (0..chip8.screen.pixel_count) |i| {
            const row = i / chip8.screen.width;
            const col = i % chip8.screen.width;

            const shift_offset: u6 = @intCast(chip8.screen.width - col - 1);

            const pixel: u1 = @truncate(machine.framebuffer[row] >> shift_offset);
            screen_pixels[i] = switch (pixel) {
                1 => WHITE,
                0 => BLACK,
            };
        }

        // Push the mutated local memory array safely across the PCIe bus pipeline
        rl.updateTexture(screen_texture, &screen_pixels);
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        // Get the window's size in case it was rescaled
        gui_state = .{
            .window_width = @intCast(rl.getScreenWidth()),
            .window_height = @intCast(rl.getScreenHeight()),
        };

        if (gui_state.window_width < panel_configs.min_screen_size * 2) {
            gui_state.tab_mode = true;
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.white);

        draw(gui_state, screen_texture);

        //----------------------------------------------------------------------------------
    }
}

fn draw(state: GuiState, screen_texture: rl.Texture) void {
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
    const panel_rect = rl.Rectangle{
        .x = screen_rect.x,
        .y = screen_rect.height + panel_configs.padding * 2,
        .width = screen_rect.width,
        .height = 300,
    };

    rgui.setStyle(
        .default,
        .{ .default = .text_size },
        24,
    );
    rgui.setStyle(
        .default,
        .{ .control = .text_alignment },
        @intFromEnum(rgui.TextAlignment.center),
    );
    _ = rgui.panel(panel_rect, "REGISTER PANEL");
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
