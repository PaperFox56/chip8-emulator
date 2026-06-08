//! By convention, root.zig is the root source file when making a package.
pub const chip8 = @import("chip8.zig");

const std = @import("std");
const Io = std.Io;
