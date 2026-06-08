//!
//! chip8/arithmetics.zig
//!
//! This file defines the ALU operations of the Chip8. Don't import this directly.

const ArithmeticFunction = (fn (*u8, *u8, *u8) void);

fn LD(VX: *u8, VY: *u8, VF: *u8) void {
    _ = VF;
    VX.* = VY.*;
}

fn OR(VX: *u8, VY: *u8, VF: *u8) void {
    _ = VF;
    VX.* |= VY.*;
}

fn AND(VX: *u8, VY: *u8, VF: *u8) void {
    _ = VF;
    VX.* &= VY.*;
}

fn XOR(VX: *u8, VY: *u8, VF: *u8) void {
    _ = VF;
    VX.* ^= VY.*;
}

fn ADD(VX: *u8, VY: *u8, VF: *u8) void {
    const result = @as(u16, VX.*) + @as(u16, VY.*);

    VF.* = if (result > 0xF) 1 else 0;

    VX.* = @truncate(result);
}

fn SUB(VX: *u8, VY: *u8, VF: *u8) void {
    VF.* = if (VX.* > VY.*) 1 else 0;

    VX.* -= VY.*;
}

fn SHR(VX: *u8, VY: *u8, VF: *u8) void {
    VF.* = VX.* & 1;
    VX.* = VX.* << 1;

    _ = VY;
}

fn SUBN(VX: *u8, VY: *u8, VF: *u8) void {
    VF.* = if (VY.* > VX.*) 1 else 0;

    VX.* = VY.* - VX.*;
}

fn SHL(VX: *u8, VY: *u8, VF: *u8) void {
    VF.* = VX.* >> 7;
    VX.* = VX.* >> 1;

    _ = VY;
}

pub const arithmetic_functions: [16]?*const ArithmeticFunction = [_]?*const ArithmeticFunction{ LD, OR, AND, XOR, ADD, SUB, SHR, SUBN, null, null, null, null, null, null, SHL, null };
