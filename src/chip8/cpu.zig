//!
//! chip8/cpu.zig
//!
//! Defines the structures and behaviours of the CHIP8 virtual machine
//!

// --------------- Imports ---------------
const arithmetic_functions = @import("arithmetics.zig").arithmetic_functions;
const Random = @import("std").Random;
// ---------------------------------------

// ------------- CHIP8 specs -------------
pub const stack_size = 16;
pub const ram_size = 0x1000; // 4096 bytes or 2^12

/// The address where the ROM is loaded in RAM. This is also the address
/// the PC register should be set to at initialisation.
pub const start_address = 0x200;

pub const screen = .{
    .width = 64,
    .height = 32,
    .pixel_count = 64 * 32,
};

// --------------------------------------

/// Represent the layout of a Chip8 instruction
/// This is useful to quickly unpack the parts of an instruction.
const Opcode = packed struct(u16) {
    nibble: u4,
    Y: u4,
    X: u4,
    group: u4,
};

/// The sprites for hexadecima digits used by the Chip8, this array will be
/// loaded in the the machine's RAM at initialisation
/// TODO: Move this outside of the virtual machine's definition. The emulator/debugger
/// should be responsible for loading th sprites.
const sprites = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

///  This structure represent's the virtual machine's state as a whole.
///  This allows the debugger to access any data at any time.
///  I also makes the emulator's core independant from any external environment.
///  That means that the same code can be reused with a different display and
///  input system.
pub const Chip8 = struct {
    // general registers
    V: [16]u8 = @splat(0),

    // stack pointer
    SP: u12 = 0,
    // program counter
    PC: u12 = start_address,
    // address register
    I: u12 = 0,

    // timer registers
    DT: u8 = 0,
    ST: u8 = 0,

    stack: [stack_size]u12 = @splat(0),
    ram: [ram_size]u8 = @splat(0),

    // Each row of the screen can be represented by a single 64 integer.
    framebuffer: [screen.height]u64 = @splat(0),
    key_released: [16]bool = @splat(false),
    key_pressed: [16]bool = @splat(false),

    rng: Random,

    pub fn init(self: *Chip8) void {
        // Load the sprites into the RAM
        @memcpy(self.ram[0..sprites.len], sprites[0..]);
    }

    //
    // Execute the instruction pointed to by the PC register and update the
    // machine's state;
    //
    pub fn step_through(self: *Chip8) void {
        // The machine is in little endian
        const high = self.ram[self.PC];
        const low = self.ram[self.PC + 1];

        const instruction: u16 = (@as(u16, high) << 8) + low;

        const op: Opcode = @bitCast(instruction);

        const address: u12 = @truncate(instruction);

        // After executing an instruction we need to know by how many steps the program counter should be incremented.
        const pc_increment: u12 = interepte: switch (op.group) {
            0x0 => {
                if (instruction == 0x00E0) { // CLS - clear the screen
                    self.framebuffer = @splat(0);
                    break :interepte 2;
                } else if (instruction == 0x00EE) { // RET - return from subroutine
                    self.SP -= 1;
                    self.PC = self.stack[self.SP];
                    break :interepte 0;
                } else {
                    // NOP
                    break :interepte 2;
                }
            },
            0x1 => { // JP addr
                self.PC = address;
                break :interepte 0;
            },
            0x2 => {
                // CALL addr
                self.stack[self.SP] = self.PC + 2;
                self.SP += 1;
                continue :interepte 0x1; // Jump
            },
            0x3 => { // SE VX, byte
                if (self.V[op.X] == low)
                    break :interepte 4;
                break :interepte 2;
            },
            0x4 => if (self.V[op.X] != low) 4 else 2, // SNE VX, byte
            0x5 => if (op.nibble == 0 and self.V[op.X] == self.V[op.Y]) 4 else 2, // SE VX, VY
            0x6 => { // LD Vx, byte
                self.V[op.X] = low;
                break :interepte 2;
            },
            0x7 => { // ADD VX, byte
                self.V[op.X] +%= low;
                break :interepte 2;
            },
            0x8 => { // ALU operations
                const func_opt = switch (op.nibble) {
                    0x0...0x7, 0xE => arithmetic_functions[op.nibble],
                    else => null,
                };

                if (func_opt) |func| {
                    func(&self.V[op.X], &self.V[op.Y], &self.V[0xF]);
                }
                break :interepte 2;
            },
            0x9 => if (op.nibble == 0 and self.V[op.X] != self.V[op.Y]) 4 else 2, // SNE VX, VY
            0xA => { // LD I, addr
                self.I = address;
                break :interepte 2;
            },
            0xB => { // JP V0, addr
                self.PC = address + self.V[0];
                break :interepte 2;
            },
            0xC => { // RND VX kk
                const random_int = self.rng.intRangeAtMost(u8, 0, 255);
                self.V[op.X] = random_int & low;
                break :interepte 2;
            },
            0xD => { // DRW VX, VY, n
                self.draw_sprite(op.X, op.Y, op.nibble);
                break :interepte 2;
            },
            0xE => {
                if (self.V[op.X] > 0xF)
                    break :interepte 2;

                if (low == 0x9E) { // SKP Vx
                    if (self.key_pressed[self.V[op.X]])
                        break :interepte 4;
                } else if (low == 0xA1) { // SKNP Vx
                    if (self.key_pressed[self.V[op.X]])
                        break :interepte 4;
                }
                break :interepte 2;
            },
            0xF => switch (low) {
                0x07 => { // LD VX, DT
                    self.V[op.X] = self.DT;
                    break :interepte 2;
                },
                0x0A => { // LD VX, K
                    for (0..16) |i| {
                        if (self.key_released[i]) {
                            self.V[op.X] = @intCast(i);
                            break :interepte 2;
                        }
                    }

                    break :interepte 0;
                },
                0x15 => { // LD DT, VX
                    self.DT = self.V[op.X];
                    break :interepte 2;
                },
                0x18 => { // LD ST, VX
                    self.ST = self.V[op.X];
                    break :interepte 2;
                },
                0x1E => { // ADD I, VX
                    self.I += self.V[op.X];
                    break :interepte 2;
                },
                0x29 => { // LD F, VX
                    self.I = self.V[op.X] * 0x05;
                    break :interepte 2;
                },
                0x33 => { // LD B, VX
                    // get hundreds, tens and ones
                    const h = self.V[op.X] / 100;
                    const t = (self.V[op.X] - h * 100) / 10;
                    const o = self.V[op.X] - h * 100 - t * 10;
                    self.ram[self.I] = h;
                    self.ram[self.I + 1] = t;
                    self.ram[self.I + 2] = o;
                    break :interepte 2;
                },
                0x55 => { // LD [I], VX
                    for (0..op.X) |i| {
                        self.ram[self.I + i] = self.V[i];
                    }
                    break :interepte 2;
                },
                0x65 => { // LD VX, [I]
                    for (0..op.X) |i| {
                        self.V[i] = self.ram[self.I + i];
                    }
                    break :interepte 2;
                },
                else => 2,
            },
            // We don't need an else here because we are switching over a u4
        };

        self.PC = @addWithOverflow(self.PC, pc_increment)[0];
    }

    ///
    /// Note is to be taken that the bitsizes of the variable used in this
    /// function have been fine tuned for the standard dimensions of the CHIP8's screen.
    ///
    fn draw_sprite(self: *Chip8, x: u4, y: u4, n: u4) void {
        // Reset collision flag
        self.V[0xF] = 0;

        // X and Y coordinates wrap according to modern Chip-8 specifications
        // Truncating here gives the same result as using the modulo operation with 64 and 32
        const start_x: u6 = @truncate(self.V[x]);
        const start_y: u5 = @truncate(self.V[y]);

        for (0..n) |i| {
            const pos_y = start_y + i;

            // Stop drawing if we hit the bottom of the screen
            if (pos_y >= screen.height)
                break;

            // Load 8-bit sprite data into the high bits of a 64-bit word
            var sprite_row = @as(u64, self.ram[self.I + i]) << 56;

            // Shift sprite to the correct horizontal position
            sprite_row >>= start_x;

            const screen_row = self.framebuffer[pos_y];

            // check for colisions
            if (sprite_row & screen_row != 0) {
                self.V[0xF] = 1;
            }

            self.framebuffer[pos_y] = sprite_row ^ screen_row;
        }
    }
};
