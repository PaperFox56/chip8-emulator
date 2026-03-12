/**
 * cpu.h
 */

#ifndef CHIP8_CPU_H
#define CHIP8_CPU_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define STACK_SIZE 16
#define RAM_SIZE 0x1000

#define SCREEN_WIDTH 64
#define SCREEN_HEIGHT 32
#define SCREEN_PIXEL_COUNT SCREEN_WIDTH *SCREEN_HEIGHT

/*
 * This structure represent's the machine as a whole.
 * This allows the debugger to access any data at any time.
 * I also makes the emulator's core independant from any external environment.
 * That means that the same code can be reused with a different display and
 * input system.
 */
typedef struct {
  // general registers
  uint8_t V[16];

  // stack pointer
  uint8_t SP;
  // program counter
  uint16_t PC;
  // address register
  uint16_t I;

  // timer registers
  uint8_t DT;
  uint8_t ST;

  uint16_t stack[STACK_SIZE];
  uint8_t RAM[RAM_SIZE];

  uint8_t framebuffer[SCREEN_PIXEL_COUNT];
  uint8_t keyboard[16];     // state of the keyboard
  uint8_t key_released[16]; // detect falling edges for key presses

} Chip8;

void Chip8_init(Chip8 *machine);

/*
 * Execute the instruction pointed to by the PC register and update the
 * machine's state;
 */
void Chip8_step_through(Chip8 *machine);

#ifdef __cplusplus
}
#endif

#endif
