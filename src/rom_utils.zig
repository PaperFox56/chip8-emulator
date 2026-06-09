const std = @import("std");
const Io = std.Io;

const LoadError = error{
    BufferTooSmall,
    FileOpenError,
    AccessError,
    ReadFailed,
};

pub fn load_ROM_from_file_descriptor(
    io: Io,
    mem: []u8,
    start: usize,
    file: Io.File,
) LoadError!void {
    const file_length = file.length(io) catch {
        // Buffer overflow
        std.debug.print("That's rough buddy\n", .{});
        return LoadError.AccessError;
    };

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
        // Try to read
        _ = reader.readSliceShort(mem) catch {
            std.debug.print("load_ROM_from_file_descriptor: Couldn't read the file, sorry\n", .{});
            return LoadError.ReadFailed;
        };
    }
}

pub fn load_ROM_from_file_path(io: Io, mem: []u8, start: usize, path: []const u8) LoadError!void {
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
