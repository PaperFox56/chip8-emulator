/**
 * arithmetic.c
 *
 * This file defines a jump table for the arithmetical instructions of the
 * Chip8.
 *
 * Each function takes as inputs pointers to the two operand registers as well
 * as the flag buffer
 */

#include <stddef.h>
#include <stdint.h>

typedef void (*arithmeticFunction)(uint8_t *, uint8_t *, uint8_t *);

void LD(uint8_t *VX, uint8_t *VY, uint8_t *VF) { *VX = *VY; }

void OR(uint8_t *VX, uint8_t *VY, uint8_t *VF) { *VX |= *VY; }

void AND(uint8_t *VX, uint8_t *VY, uint8_t *VF) { *VX &= *VY; }

void XOR(uint8_t *VX, uint8_t *VY, uint8_t *VF) { *VX ^= *VY; }

void ADD(uint8_t *VX, uint8_t *VY, uint8_t *VF) {
  uint16_t result = *VX + *VY;

  if (result > 0xF)
    *VF = 1;
  else
    *VF = 0;

  *VX = result & 0xF;
}

void SUB(uint8_t *VX, uint8_t *VY, uint8_t *VF) {
  if (*VX > *VY)
    *VF = 1;
  else
    *VF = 0;

  *VX -= *VY;
}

void SHR(uint8_t *VX, uint8_t *VY, uint8_t *VF) {
  *VF = *VX & 1;
  *VX = *VX << 1;
}

void SUBN(uint8_t *VX, uint8_t *VY, uint8_t *VF) {
  if (*VY > *VX)
    *VF = 1;
  else
    *VF = 0;

  *VX = *VY - *VX;
}

void SHL(uint8_t *VX, uint8_t *VY, uint8_t *VF) {
  *VF = *VX >> 7;
  *VX = *VX >> 1;
}

arithmeticFunction arithmetic_functions[] = {LD,   OR,   AND,  XOR,  ADD,
                                             SUB,  SHR,  SUBN, NULL, NULL,
                                             NULL, NULL, NULL, NULL, SHL};
