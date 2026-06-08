const std = @import("std");
const Io = std.Io;

const chemuz = @import("chemuz8_core");
pub const gui = @import("gui/display.zig");
//pub const tui = @import("tui/display.zig");

pub fn main() !void {

    // We need to feed an rng to the machine
    // We will seed it with the system time
    var rng = std.Random.DefaultPrng.init(4);
    const rand = rng.random();

    var machine = chemuz.chip8.Chip8{ .rng = rand };
    machine.init();
    machine.step_through();

    std.debug.print("The machine is runnig\n", .{});
}
