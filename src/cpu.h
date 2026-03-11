#ifndef CHIP8_CPU_H
#define CHIP8_CPU_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define STACK_SIZE 16
#define RAM_SIZE 0x1000

typedef struct {
  // general registers
  uint8_t V[0xF];

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
} CPU;

void CPU_init(CPU *cpu);

uint8_t get_random_number();

#ifdef __cplusplus
}
#endif

#endif