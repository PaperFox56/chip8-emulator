#include <stdint.h>
#include <stdlib.h>

#include "cpu.h"

void CPU_init(CPU *cpu);

uint8_t get_random_number() {
  // Allocate a memory location, read the address and apply arbitrary functions
  // to it and voila

  uint64_t *addr = malloc(sizeof(uint64_t));

  uint64_t rand = (uint64_t)addr + *addr;
  free(addr);

  return (rand * 0x1777323) & 0xFF;
}