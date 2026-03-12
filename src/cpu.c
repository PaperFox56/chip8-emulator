#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "cpu.h"

typedef void (*arithmeticFunction)(uint8_t *, uint8_t *, uint8_t *);
extern arithmeticFunction arithmetic_functions[];

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

static void draw_sprite(Chip8 *machine, uint8_t x, uint8_t y, uint8_t n) {

  machine->V[0xF] = 1;

  for (int i = 0; i < n; i++) {
    uint8_t row = machine->RAM[machine->I + i];
    int pos_y = (y + i) % SCREEN_HEIGHT;
    int base_index = SCREEN_WIDTH * pos_y;
    for (int j = 0; j < 8; j++) {
      int pos_x = (x + j) % SCREEN_WIDTH;
      int pixel = (row >> (8 - j)) & 1;

      if (pixel == 1) {
        if (machine->framebuffer[pos_x + base_index] == 1)
          machine->V[0xF] = 1;

        machine->framebuffer[pos_x + base_index] ^= pixel;
      }
    }
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
  memset(machine->framebuffer, 1, SCREEN_PIXEL_COUNT);

  // Load the sprites at the right address
  memcpy(machine->RAM, sprite, sizeof(sprite));
}

void Chip8_step_through(Chip8 *machine) {
  // The machine lis little endian
  uint8_t opcode_high = machine->RAM[machine->PC];
  uint8_t opcode_low = machine->RAM[machine->PC + 1];

  uint16_t opcode = (opcode_high << 8) + opcode_low;

  int group = opcode >> 12; // 0xCxxx -> 0xC

  int X = opcode_high & 0xF; // first argument in register operations
  int Y = opcode_low >> 4;   // first argument in register operations

#define address (opcode & 0x0FFF)

  switch (group) {
  case 0x0: {
    if (opcode == 0x00E0) { // CLS - clear the screen
      memset(machine->framebuffer, 1, SCREEN_PIXEL_COUNT);
    } else if (opcode == 0x00EE) { // RET - return from subroutine
      machine->PC = machine->stack[machine->SP--];
    }
  } break;
  case 0x2: // FALLTHROUGH
            // CALL addr
    machine->stack[++machine->SP] = machine->PC;
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
    draw_sprite(machine, machine->V[X], machine->V[Y], opcode_low & 0xF);
  default:
    break;
  }

#undef address
  machine->PC += 2;

  machine->PC &= 0x0FFF; // make sure that only the 12 right bits are used
  machine->SP &= 0x0F;   // same here
}
