//!
//! debugger.zig
//!
//! Source code for the pure debugging capabilities.
//! The graphical interface as well as the terminal interface (if there is one)
//! can be plugged to it.
//!

const Chip8 = @import("../chip8/cpu.zig").Chip8;

const Debugger = struct {
    machine: *Chip8,
};
