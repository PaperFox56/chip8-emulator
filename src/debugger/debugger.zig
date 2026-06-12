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
const disassembler = @import("disassembler.zig");

pub const disassemble = disassembler.disassemble_opcode;

const chip8_specs = .{
    .target_cpu_frequency = 600, // in Hz
    .timer_frequency = 60, //in Hz
};

pub const DebuggerError = error{
    LoadRom,
};

// mesures time in nanoseconds
const time_t = u96;
const ONE_SECOND: time_t = 1_000_000_000;

pub const Debugger = struct {
    machine: *Chip8,
    paused: bool = true,

    // Timing related variables
    time_since_last_cpu_instruction: time_t = 0, // in ns
    time_since_last_timer_update: time_t = 0, // in ns

    emulation_speed: time_t = 100, // in percents

    /// Should be called before ANY call to `update`
    pub fn init(self: *Debugger, time: time_t) void {
        self.time_since_last_cpu_instruction = time;
        self.time_since_last_timer_update = time;
    }

    /// Before calling this method, make sure that you called `init` just before you mainloop.
    ///
    /// This function is what allows the debugger to be completely
    /// independant from an interface.
    ///
    /// When called, the parameter `time` will be used to decide
    /// wether to execute the next instruction in the virtual machine, update the timers and more.
    ///
    /// The emulation speed is taken in account for those calculation.
    ///
    /// This function's implementation should only make atomic changes to the virtual machine
    /// (execute only one instruction, decrement the timers only once) and will not try to compensate
    /// for time delays caused by the external code.
    ///
    /// Note one the `time`. No matter where this value come from, only one thing needs to be
    /// guaranted by the caller: THE TIME SHOULD BE A MONOTONE QUANTITY! Although this function does no
    /// explicitely relie on it, making sure that it is always the case could avoid wierd untracable bugs.
    ///
    /// For debuggin reasons, returns true if a cpu instruction was executed.
    ///
    pub fn update(self: *Debugger, time: time_t) bool {
        if (self.paused) {
            return false;
        }

        const target_time_per_timer_update = ONE_SECOND / chip8_specs.timer_frequency;
        const emulation_target_time_per_timer_update = 100 * target_time_per_timer_update / self.emulation_speed;

        if (time - self.time_since_last_timer_update >= emulation_target_time_per_timer_update) {
            self.time_since_last_timer_update += emulation_target_time_per_timer_update;
            self.machine.DT -|= 1;
            self.machine.ST -|= 1;
        }

        const target_time_per_cpu_instruction = ONE_SECOND / chip8_specs.target_cpu_frequency;
        const emulation_target_time_per_cpu_instruction = 100 * target_time_per_cpu_instruction / self.emulation_speed;

        if (time - self.time_since_last_cpu_instruction >= emulation_target_time_per_cpu_instruction) {
            self.time_since_last_cpu_instruction += emulation_target_time_per_cpu_instruction;
            self.machine.step_through();
            return true;
        } else {
            return false;
        }
    }

    pub fn load_ROM(self: *Debugger, io: std.Io, path: []const u8) DebuggerError!void {
        self.machine.ram = @splat(0);
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

        self.machine.PC = chip8.start_address;
        self.machine.framebuffer = @splat(0);
        self.paused = true;
    }
};
