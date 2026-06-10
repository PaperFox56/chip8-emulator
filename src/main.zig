const std = @import("std");
const Io = std.Io;

const chemuz = @import("chemuz8_core");
pub const gui = @import("gui/gui.zig");
//pub const tui = @import("tui/display.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // We need to feed an rng to the machine
    // We will seed it with the system time
    var rng = std.Random.DefaultPrng.init(4);
    const rand = rng.random();

    var machine = chemuz.chip8.Chip8{ .rng = rand };
    var debugger = chemuz.debugger.Debugger{ .machine = &machine };
    try debugger.load_ROM(
        io,
        "testROMs/test_opcode.ch8",
    );

    std.debug.print("The machine is running\n", .{});

    try gui.run(io, &debugger);

    std.debug.print("Goodbye\n", .{});
}
