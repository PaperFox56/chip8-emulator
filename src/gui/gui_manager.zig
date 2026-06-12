const std = @import("std");

pub const GuiState = struct {
    window_width: u32,
    window_height: u32,

    tab_mode: bool = false,
    // If true, the disassembly panel will be centered around
    // the current instruction address
    follow_PC: bool = true,

    // Keys
    pause_key_pressed: bool = false,

    // Widgets
    speed_spiner_edit: bool = false,
    speed_spiner_value: i32 = 100,

    // Input text for each register
    V: [16]TextBoxManager = undefined,
    specials: [3]TextBoxManager = undefined,
    timers: [2]TextBoxManager = undefined,
};

/// Maps a single hardware register to its visual layout metadata
pub const RegisterMap = struct {
    name: [:0]const u8,
    val_ptr: *anyopaque,
    manager: *TextBoxManager,
};

pub const TextBoxManager = struct {
    active: bool = true,
    edit_mode: bool = false,

    // No textbox will need more than 4 hex characters
    buffer: [5:0]u8 = @splat(0),
    // For later
    read_breakpoint: bool = false,
    write_breakpoint: bool = true,

    pub fn build_many(dest: []TextBoxManager) void {
        for (0..dest.len) |i| {
            dest[i] = .{};
        }
    }

    /// Try to parse the input of the textbox as an hexadecimal number
    pub fn getIntValue(self: *TextBoxManager, comptime T: type) ?T {
        if ((@typeInfo(T) != .int) or @bitSizeOf(T) > 16) {
            @compileError("Type '" ++ @typeName(T) ++ "' is not a supported type!");
        }
        const s: [*:0]u8 = self.buffer[0..];
        const clean_slice: []u8 = std.mem.span(s);
        return std.fmt.parseUnsigned(T, clean_slice, 16) catch null;
    }

    pub fn fillFromInt(self: *TextBoxManager, comptime T: type, num: T) void {
        if ((@typeInfo(T) != .int) or (@bitSizeOf(T) > 16)) {
            @compileError("Validation failed: Type '" ++ @typeName(T) ++ "' is not a supported type!");
        }

        const fmt_string = cal: {
            comptime {
                // Calculate how many hex characters this type occupies (4 bits per hex character)
                const bit_count = @typeInfo(T).int.bits;
                const digit_count = ceilDiv(comptime_int, bit_count, 4);

                const digits_str = std.fmt.comptimePrint("{d}", .{digit_count});

                break :cal "{X:0>" ++ digits_str ++ "}\x00";
            }
        };

        self.buffer = @splat(0);
        _ = std.fmt.bufPrint(&self.buffer, fmt_string, .{num}) catch unreachable;
    }
};

// Performs `a/b` but rounded to the next integer
pub fn ceilDiv(comptime T: type, a: T, b: T) T {
    if (@typeInfo(T) != .int and T != comptime_int) {
        @compileError("Validation failed: Type '" ++ @typeName(T) ++ "' is not an integer type!");
    }

    if (b == 0) {
        @compileError("There is no way this was not made on purpose");
    }

    return (a + b - 1) / b;
}
