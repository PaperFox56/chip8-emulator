#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "cpu.h"

typedef void (*arithmeticFunction)(uint8_t *, uint8_t *, uint8_t *);
extern arithmeticFunction arithmetic_functions[];


// the sprites for hexadecimal digits.S
static const uint8_t sprite[] = {
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

static uint8_t get_random_number() { return rand() % 256; }

// Rotate 64-bit integer right by 'n' bits
uint64_t rotate_right(uint64_t x, unsigned int n) {
  const uint32_t mask = (8 * sizeof(x)) - 1;
  n &= mask; // Ensure n is in the range [0, 63]
  if (n == 0)
    return x;
  return (x << n) | (x >> ((-n) & mask));
}

static void draw_sprite(Chip8 *machine, uint8_t x, uint8_t y, uint8_t n) {
  // Reset collision flag
  machine->V[0xF] = 0;

  // X and Y coordinates wrap according to modern Chip-8 specifications
  uint8_t start_x = machine->V[x] % SCREEN_WIDTH;
  uint8_t start_y = machine->V[y] % SCREEN_HEIGHT;

  for (int i = 0; i < n; i++) {
    int pos_y = (start_y + i);
    // Stop drawing if we hit the bottom of the screen
    if (pos_y >= SCREEN_HEIGHT)
      break;

    // Load 8-bit sprite data into the high bits of a 64-bit word
    uint64_t sprite_row = (uint64_t)machine->RAM[machine->I + i] << 56;

    // Shift sprite to the correct horizontal position
    sprite_row >>= start_x;

    uint64_t screen_row = machine->framebuffer[pos_y];

    if (sprite_row & screen_row) {
      machine->V[0xF] = 1;
    }

    machine->framebuffer[pos_y] = sprite_row ^ screen_row;
  }
}

void Chip8_init(Chip8 *machine) {
  // Seed the random number generator
  srand(time(NULL));

  // Initialize the CPU's fields
  memset(machine->V, 0, 16);

  machine->PC = 0x200;
  machine->SP = 0;
  machine->I = 0;

  machine->DT = 0;
  machine->ST = 0;

  // The stack holds 16 bits values (2 bytes)
  memset(machine->stack, 0, STACK_SIZE * 2);
  memset(machine->RAM, 0, RAM_SIZE);
  memset(machine->framebuffer, 0, SCREEN_HEIGHT);
  memset(machine->keyboard, 0, 16);
  memset(machine->key_released, 0, 16);

  // Load the sprites at the right address
  memcpy(machine->RAM, sprite, sizeof(sprite));
}

void Chip8_step_through(Chip8 *machine) {
  // The machine lis little endian
  uint8_t opcode_high = machine->RAM[machine->PC];
  uint8_t opcode_low = machine->RAM[machine->PC + 1];

  uint16_t opcode = (opcode_high << 8) + opcode_low;

  int group = opcode_high >> 4; // 0xCxxx -> 0xC

  int X = opcode_high & 0xF; // first argument in register operations
  int Y = opcode_low >> 4;   // first argument in register operations

  machine->PC += 2;

#define address (opcode & 0x0FFF)

  switch (group) {
  case 0x0: {
    if (opcode_low == 0x00E0) { // CLS - clear the screen
      memset(machine->framebuffer, 0, SCREEN_HEIGHT * sizeof(uint64_t));
    } else if (opcode == 0x00EE) { // RET - return from subroutine
      machine->PC = machine->stack[machine->SP--];
    }
  } break;
  case 0x2: // FALLTHROUGH
            // CALL addr
    machine->stack[++machine->SP] = machine->PC + 2;
  case 0x1: // JP addr
    machine->PC = address;
    break;
  case 0x3: // SE VX, byte
    if (machine->V[X] == opcode_low)
      machine->PC += 2;
    break;
  case 0x4: // SNE VX, byte
    if (machine->V[X] != opcode_low)
      machine->PC += 2;
    break;
  case 0x5: {
    if ((opcode_low & 0xF) == 0) { // SE VX, VY

      if (machine->V[X] == machine->V[Y])
        machine->PC += 2;
    }
  } break;
  case 0x6: // LD Vx, byte
    machine->V[X] = opcode_low;
    break;
  case 0x7: // ADD VX, byte
    machine->V[X] += opcode_low;
    break;
  case 0x8: {
    int variant = opcode_low & 0xF;
    uint8_t *r_base = machine->V;
    if ((variant >= 0x0 && variant <= 0x7) || variant == 0xE)
      arithmetic_functions[variant](r_base + X, r_base + Y, r_base + 0xF);
  } break;
  case 0x9:
    if ((opcode_low & 0xF) == 0) { // SNE VX, VY
      if (machine->V[X] != machine->V[Y])
        machine->PC += 2;
    }
    break;
  case 0xA: // LD I, addr
    machine->I = address;
    break;
  case 0xB: // JP V0, addr
    machine->PC = address + machine->V[0];
    break;
  case 0xC: // RND VX kk
    machine->V[X] = get_random_number() & opcode_low;
    break;
  case 0xD: // DRW VX, VY, n
    draw_sprite(machine, X, Y, opcode_low & 0xF);
    break;
  case 0xE: {
    if (machine->V[X] > 0xF)
      break;

    if ((opcode_low & 0x9E) == 0) { // SKP Vx
      if (machine->keyboard[machine->V[X]] != 0)
        machine->PC += 2;
    } else if ((opcode_low & 0xA1) == 0) { // SKNP Vx
      if (machine->keyboard[machine->V[X]] == 0)
        machine->PC += 2;
    }
  } break;
  case 0xF:
    switch (opcode_low) {
    case 0x07: // LD VX, DT
      machine->V[X] = machine->DT;
      break;
    case 0x0A: { // LD VX, K
      int found = 0;
      for (int i = 0; i < 16; i++) {
        if (machine->key_released[i] != 0) {
          machine->V[X] = i;
          found = 1;
          break;
        }
      }

      if (!found) {
        machine->PC -= 2;
      }
    } break;
      ;
    case 0x15: // LD DT, VX
      machine->DT = machine->V[X];
      break;
      ;
    case 0x18: // LD ST, VX
      machine->ST = machine->V[X];
      break;
    case 0x1E: // ADD I, VX
      machine->I += machine->V[X];
      break;
    case 0x29: // LD F, VX
      machine->I = machine->V[X] * 0x05;
      break;
    case 0x33: { // LD B, VX
                 // get hundreds, tens and ones
      uint8_t h = machine->V[X] / 100;
      uint8_t t = (machine->V[X] - h * 100) / 10;
      uint8_t o = machine->V[X] - h * 100 - t * 10;
      machine->RAM[machine->I] = h;
      machine->RAM[machine->I + 1] = t;
      machine->RAM[machine->I + 2] = o;
    } break;
    case 0x55: // LD [I], VX
      for (int i = 0; i <= X; i++) {
        machine->RAM[machine->I + i] = machine->V[i];
      }
      break;
    case 0x65: // LD VX, [I]
      for (int i = 0; i <= X; i++) {
        machine->V[i] = machine->RAM[machine->I + i];
      }
      break;
    default:
      break;
    }
  }

#undef address

  machine->SP &= 0x0F; // same here
}
