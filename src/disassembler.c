#include <stdio.h>
#include <string.h>
#include <teye/char_buffer.h>

#include "common.h"
#include "disassembler.h"

int disassemble_opcode(char *buffer, unsigned int size, uint8_t opcode_high,
                       uint8_t opcode_low) {
  if (buffer == NULL) {
    fprintf(stderr, "disassemble_opcode: The provided buffer was invalid.");
  }

  // It will make it easier to count the number of characters
  struct CharBuffer temp;
  CharBuffer_init(&temp);

  uint16_t opcode = (opcode_high << 8) + opcode_low;

  int group = opcode_high >> 4; // 0xCxxx -> 0xC

  int X = opcode_high & 0xF; // first argument in register operations
  int Y = opcode_low >> 4;   // first argument in register operations

#define address (opcode & 0x0FFF)
#define push_string(s) CharBuffer_append_string(&temp, s)
#define push_hex(n, d) CharBuffer_append_hex(&temp, n, d)
#define push_int(n) CharBuffer_append_int(&temp, n)

  switch (group) {
  case 0x0: {
    if (opcode == 0x00E0) { // CLS - clear the screen
      push_string("CLS");
    } else if (opcode == 0x00EE) { // RET - return from subroutine
      // TODO: Add the return address (from the stack)
      push_string("RET");
    } else {
      push_string("SYS ");
      push_hex(opcode & 0x0FFF, 3);
    }
  } break;

  case 0x2:
    // CALL addr
    push_string("CALL ");
    push_hex(address, 3);
    break;
  case 0x1: // JP addr
    push_string("JP ");
    push_hex(address, 3);
    break;
  case 0x3: // SE VX, byte
    push_string("SE V");
    push_hex(X, 1);
    push_string(" ");
    push_hex(opcode_low, 2);
    break;
  case 0x4: // SNE VX, byte
    push_string("SNE V");
    push_hex(X, 1);
    push_string(" ");
    push_hex(opcode_low, 2);
    break;
  case 0x5: {
    push_string("SE V");
    push_hex(X, 1);
    push_string(" V");
    push_hex(Y, 1);
  } break;
  case 0x6: // LD Vx, byte
    push_string("LD V");
    push_hex(X, 1);
    push_string(" ");
    push_hex(opcode_low, 2);
    break;
  case 0x7: // ADD VX, byte
    push_string("ADD V");
    push_hex(X, 1);
    push_string(" ");
    push_hex(opcode_low, 2);
    break;
  case 0x8: {
    int variant = opcode_low & 0xF;
    switch (variant) {
    case 0x0:
      push_string("LD V");
      break;
    case 0x1:
      push_string("OR V");
      break;
    case 0x2:
      push_string("AND V");
      break;
    case 0x3:
      push_string("XOR V");
      break;
    case 0x4:
      push_string("ADD V");
      break;
    case 0x5:
      push_string("SUB V");
      break;
    case 0x6:
      push_string("SHR V");
      break;
    case 0x7:
      push_string("SUBN V");
      break;
    case 0xE:
      push_string("SHL V");
      break;
    default:
      break;
    }
    push_hex(X, 1);
    push_string(" V");
    push_hex(Y, 1);
  } break;
  case 0x9:
    push_string("SNE V");
    push_hex(X, 1);
    push_string(" V");
    push_hex(Y, 1);
    break;
  case 0xA: // LD I, addr
    push_string("LD I ");
    push_hex(opcode & 0xFFF, 3);
    break;
  case 0xB: // JP V0, addr
    push_string("JP V0 ");
    push_hex(opcode & 0xFFF, 3);
    break;
  case 0xC: // RND VX kk
    push_string("RND V");
    push_hex(X, 1);
    push_string(" ");
    push_hex(opcode_low, 2);
    break;
  case 0xD: // DRW VX, VY, n
    push_string("DRW V");
    push_hex(X, 1);
    push_string(" V");
    push_hex(Y, 1);
    push_string(" ");
    push_hex(opcode_low & 0xF, 1);
    break;
  case 0xE: {
    if (opcode_low == 0x9E) { // SKP Vx
      push_string("SKP V");
      push_hex(X, 1);
    } else if (opcode_low == 0xA1) { // SKNP Vx
      push_string("SKNP V");
      push_hex(X, 1);
    }
  } break;
  case 0xF:
    switch (opcode_low) {
    case 0x07: // LD VX, DT
      push_string("LD V");
      push_hex(X, 1);
      push_string(" DT");
      break;
    case 0x0A: { // LD VX, K
      push_string("LD V");
      push_hex(X, 1);
      push_string(" K");
    } break;
      ;
    case 0x15: // LD DT, VX
      push_string("LD DT V");
      push_hex(X, 1);
      break;
    case 0x18: // LD ST, VX
      push_string("LD ST V");
      push_hex(X, 1);
      break;
    case 0x1E: // ADD I, VX
      push_string("ADD I V");
      push_hex(X, 1);
      break;
    case 0x29: // LD F, VX
      push_string("LD F V");
      push_hex(X, 1);
      break;
    case 0x33: { // LD B, VX
                 // get hundreds, tens and ones
      push_string("LD B V");
      push_hex(X, 1);
    } break;
    case 0x55: // LD [I], VX
      push_string("LD [I] V");
      push_hex(X, 1);
      break;
    case 0x65: // LD VX, [I]
      push_string("LD V");
      push_hex(X, 1);
      push_string(" [I]");
    }
    break;
  default:
    break;
  }

#undef address

  if (temp.len > size) {
    fprintf(stderr,
            "disassemble_opcode: The provided buffer was too small > buffer "
            "size: %d, number of bytes: %ld",
            size, temp.len);
    return -1;
  }

  strcpy(buffer, temp.buf);
  size = temp.len;

  CharBuffer_free(&temp);

  return size;
}
