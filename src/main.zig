const std = @import("std");
const Io = std.Io;

const chemuz = @import("chemuz8_core");
pub const gui = @import("gui/display.zig");
//pub const tui = @import("tui/display.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // We need to feed an rng to the machine
    // We will seed it with the system time
    var rng = std.Random.DefaultPrng.init(4);
    const rand = rng.random();

    var machine = chemuz.chip8.Chip8{ .rng = rand };
    try load_ROM_from_file_path(
        io,
        machine.ram[chemuz.chip8.start_address..],
        0,
        "testROMs/test_opcode.ch8",
    );

    std.debug.print("The machine is running\n", .{});

    try gui.run(&machine);

    std.debug.print("Goodbye\n", .{});
}

const LoadError = error{
    BufferTooSmall,
    FileOpenError,
};

fn load_ROM_from_file_descriptor(
    io: Io,
    mem: []u8,
    start: usize,
    file: Io.File,
) !void {
    const file_length = try file.length(io);

    if (file_length <= start) {
        // Nothing to read
        return;
    }

    const to_read = file_length - start;

    if (to_read > mem.len) {
        // Buffer overflow
        std.debug.print(
            \\load_ROM_from_file_descriptor: Buffer size is less 
            \\than data length\n
        , .{});
        return LoadError.BufferTooSmall;
    } else {
        var file_reader = file.reader(io, &.{});

        const reader = &file_reader.interface;
        _ = try reader.readSliceShort(mem);
        return;
    }
}

fn load_ROM_from_file_path(io: Io, mem: []u8, start: usize, path: []const u8) !void {
    // open the file in read binary mode
    const cwd = Io.Dir.cwd();
    const file = cwd.openFile(io, path, .{
        .mode = .read_only,
    }) catch |err| {
        std.debug.print(
            "load_ROM_from_file_path: Couldn't open ROM file '{s}': {any}\n",
            .{ path, err },
        );
        return LoadError.FileOpenError;
    };

    defer file.close(io);

    load_ROM_from_file_descriptor(io, mem, start, file) catch |err| {
        std.debug.print("load_ROM_from_file_path: Error while loading the file's data\n", .{});
        return err;
    };
}
