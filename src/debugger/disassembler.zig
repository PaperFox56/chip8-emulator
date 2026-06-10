const std = @import("std");

const Opcode = @import("../chip8/cpu.zig").Opcode;

const OpcodeFmt = struct {
    start: []const u8,
    end: []const u8 = "",
    X: bool = false,
    Y: bool = false,
    n: bool = false,
    nn: bool = false,
    nnn: bool = false,
};

pub fn format_opcode(buffer: []u8, fmt: OpcodeFmt, op: Opcode) []u8 {
    const opcode: u16 = @bitCast(op);

    const nn_val = opcode & 0x00FF;
    const nnn_val = opcode & 0x0FFF;

    var p_bufs = [_][16]u8{undefined} ** 5;

    // Track dynamic slice segments up to 5 potential parameters
    var parts: [5][]const u8 = undefined;
    var count: usize = 0;

    // 3. Incrementally format active template nodes sequentially
    if (fmt.X) {
        parts[count] = std.fmt.bufPrint(&p_bufs[count], "[V{X}]", .{op.X}) catch "??";
        count += 1;
    }
    if (fmt.Y) {
        parts[count] = std.fmt.bufPrint(&p_bufs[count], "[V{X}]]", .{op.Y}) catch "??";
        count += 1;
    }
    if (fmt.n) {
        parts[count] = std.fmt.bufPrint(&p_bufs[count], "#{X}", .{op.nibble}) catch "??";
        count += 1;
    }
    if (fmt.nn) {
        parts[count] = std.fmt.bufPrint(&p_bufs[count], "#{X:0>2}", .{nn_val}) catch "??";
        count += 1;
    }
    if (fmt.nnn) {
        parts[count] = std.fmt.bufPrint(&p_bufs[count], "#{X:0>3}", .{nnn_val}) catch "??";
        count += 1;
    }

    var join_buf: [64]u8 = @splat(0);
    const middle = switch (count) {
        0 => "",
        1 => parts[0],
        2 => std.fmt.bufPrint(&join_buf, "{s}, {s}", .{ parts[0], parts[1] }) catch "",
        // CHIP-8 instructions never have 3 or more comma-separated arguments,
        // but we handle it safely to keep the compiler happy.
        else => std.fmt.bufPrint(&join_buf, "{s}, {s}, {s}\x00", .{ parts[0], parts[1], parts[2] }) catch "",
    };

    return std.fmt.bufPrint(buffer, "{s} {s} {s}", .{ fmt.start, middle, fmt.end }) catch unreachable;
}

test "format_opcode" {
    const buffer: [32]u8 = undefined;

    try std.testing.expectEqual("OR V2, V3", format_opcode(
        buffer,
        OpcodeFmt{ .start = "OR" },
        @bitCast(0x8233),
    ));
}

pub fn disassemble_opcode(buffer: []u8, opcode: u16) [:0]u8 {
    const op: Opcode = @bitCast(opcode);

    const fmt: OpcodeFmt = switch (op.group) {
        0x0 => if (opcode == 0x00E0) // CLS - clear the screen
            .{ .start = "CLS" }
        else if (opcode == 0x00EE) // RET - return from subroutine
            // TODO: Add the return address (from the stack)
            .{ .start = "CLS" }
        else
            .{ .start = "SYS" },
        0x1 => // JP addr
        .{ .start = "JP", .nnn = true },
        0x2 => // CALL addr
        .{ .start = "CALL", .nnn = true },
        0x3 => // SE VX, byte
        .{ .start = "SE", .X = true, .nn = true },
        0x4 => // SNE V, byte
        .{ .start = "SNE", .X = true, .nn = true },
        0x5 => // SE VX, VY
        .{ .start = "SE", .X = true, .Y = true },
        0x6 => // LD VX, byte
        .{ .start = "LD", .X = true, .nn = true },
        0x7 => // ADD VX, byte
        .{ .start = "ADD", .X = true, .nn = true },
        0x8 => switch (op.nibble) {
            0x0 => .{ .start = "LD", .X = true, .Y = true },
            0x1 => .{ .start = "OR", .X = true, .Y = true },
            0x2 => .{ .start = "AND", .X = true, .Y = true },
            0x3 => .{ .start = "XOR", .X = true, .Y = true },
            0x4 => .{ .start = "ADD", .X = true, .Y = true },
            0x5 => .{ .start = "SUB", .X = true, .Y = true },
            0x6 => .{ .start = "SHR", .X = true },
            0x7 => .{ .start = "SUBN", .X = true, .Y = true },
            0xE => .{ .start = "SHL", .X = true },
            else => .{ .start = "NOP" },
        },
        0x9 => // SNE VX, VY
        .{ .start = "SNE", .X = true, .Y = true },
        0xA => // LD I, addr
        .{ .start = "LD I,", .nnn = true },
        0xB => // JP V0, addr
        .{ .start = "JP V0,", .nnn = true },
        0xC => // RND VX, kk
        .{ .start = "RND", .X = true, .nn = true },
        0xD => // DRW VX, VY, n
        .{ .start = "DRW", .X = true, .Y = true, .n = true },
        0xE => if (opcode & 0xFF == 0x9E) // SKP Vx
            .{ .start = "SKP", .X = true }
        else if (opcode & 0xFF == 0xA1) // SKNP Vx
            .{ .start = "SKNP", .X = true }
        else
            .{ .start = "NOP" },
        0xF => switch (opcode & 0xFF) {
            0x07 => // LD VX, DT
            .{ .start = "LD", .X = true, .end = ", DT" },
            0x0A => // LD VX, K
            .{ .start = "LD", .X = true, .end = ", K" },
            0x15 => // LD DT, VX
            .{ .start = "LD DT,", .X = true },
            0x18 => // LD ST, VX
            .{ .start = "LD ST,", .X = true },
            0x1E => // ADD I, VX
            .{ .start = "ADD I,", .X = true },
            0x29 => // LD F, VX
            .{ .start = "LD F,", .X = true },
            0x33 => // LD B, VX
            .{ .start = "LD B,", .X = true },
            0x55 => // LD [I], VX
            .{ .start = "LD [I],", .X = true },
            0x65 => // LD VX, [I]
            .{ .start = "LD", .X = true, .end = ", [I]" },
            else => .{ .start = "NOP" },
        },
    };

    const result = format_opcode(buffer, fmt, op);
    return @ptrCast(result);
}
