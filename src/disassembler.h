#ifndef CHIP8_DISASSEMBLER_H
#define CHIP8_DISASSEMBLER_H

#include <stdint.h>
int disassemble_opcode(char *buffer, unsigned int size, uint8_t opcode_high,
                       uint8_t opcode_low);

#endif
