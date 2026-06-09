//!
//! debugger.zig
//!
//! Source code for the pure debugging capabilities.
//! The graphical interface as well as the terminal interface (if there is one)
//! can be plugged to it.
//!
const std = @import("std");

const chip8 = @import("../chip8/cpu.zig");
const Chip8 = chip8.Chip8;
const rom_utils = @import("../rom_utils.zig");

const chip8_specs = .{
    .target_cpu_frequency = 600.0, // in Hz
    .clock_frequency = 60.0, //in Hz
};

pub const DebuggerError = error{
    LoadRom,
};

pub const Debugger = struct {
    machine: *Chip8,
    paused: bool = true,

    pub fn init(self: *Debugger) void {
        _ = self;
    }

    pub fn update(self: *Debugger) void {
        if (!self.paused) {
            self.machine.step_through();
        }
    }

    pub fn load_ROM(self: *Debugger, io: std.Io, path: []const u8) DebuggerError!void {
        rom_utils.load_ROM_from_file_path(
            io,
            self.machine.ram[chip8.start_address..],
            0,
            path,
        ) catch {
            std.debug.print(
                "Chip8_Debugger_load_ROM: Couldn't load the ROM in file '{s}'\n",
                .{path},
            );
            return DebuggerError.LoadRom;
        };
    }
};
