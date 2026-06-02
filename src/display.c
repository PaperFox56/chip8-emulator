#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <teye/teye.h>
#include <unistd.h>

#include "cpu.h"
#include "display.h"
#include "teye/char_buffer.h"

#define BLACK 232
#define WHITE 231

static TEYE_Buffer chip8_screen = {0};

static struct CharBuffer screen_buffer;

static void clean() {
  CharBuffer_free(&screen_buffer);
  TEYE_free_buffer(&chip8_screen);
  TEYE_free();
}

/**
 * Fast Cursor Move: "\x1b[row;colH"
 */
static void CharBuffer_append_cursor_move(struct CharBuffer *cb, int row,
                                          int col) {
  CharBuffer_append_text(cb, "\x1b[", 2);
  CharBuffer_append_int(cb, row);
  CharBuffer_append_text(cb, ";", 1);
  CharBuffer_append_int(cb, col);
  CharBuffer_append_text(cb, "H", 1);
}

int Display_init() {

  if (CharBuffer_init(&screen_buffer) != 0) {
    return -1;
  }

  if (TEYE_allocate_buffer(&chip8_screen, SCREEN_WIDTH, SCREEN_HEIGHT) != 0) {
    CharBuffer_free(&screen_buffer);
    return -1;
  }

  TEYE_init(HANDLE_RESIZE);

  atexit(clean);

  return 0;
}

void Display_update(const Chip8 *machine) {
  // We need to convert the chip8's framebuffer to a proper TEYE buffer
  for (int i = 0; i < SCREEN_HEIGHT; i++) {
    for (int j = 0; j < SCREEN_WIDTH; j++) {
      chip8_screen.buffer[i * SCREEN_WIDTH + j] =
          ((machine->framebuffer[i] >> (63 - j)) & 1) ? WHITE : BLACK;
    }
  }

  Display_render();
}

void Display_render() {
  TEYE_blit(chip8_screen, FitWidth, 0, 0);
  TEYE_render_frame();

  TEYE_Buffer teye_frame_buffer = TEYE_get_framebuffer(0);

  CharBuffer_append_cursor_move(&screen_buffer,
                                (teye_frame_buffer.height + 1) / 4, 0);

  write(STDOUT_FILENO, screen_buffer.buf, screen_buffer.len);
  screen_buffer.len = 0;

  fflush(stdout);
}

const char digits[] = "0123456789ABCDEF";

void CharBuffer_append_hex(struct CharBuffer *char_buffer, unsigned int num) {
  char temp[8];

  int i = 8;
  while (num > 0 || (i % 2) != 0 || i == 8) {
    i--;
    temp[i] = digits[num & 0xF];
    num >>= 4;
  }

  fprintf(stderr, "%d\n", i);

  CharBuffer_append_text(char_buffer, temp + i, 8 - i);
}

void CharBuffer_append_string(struct CharBuffer *charbuffer, const char *s) {
  CharBuffer_append_text(charbuffer, s, strlen(s));
}

#define min(a, b) (a < b ? a : b)
#define max(a, b) (a > b ? a : b)

void display_debugging_information(const Chip8 *machine) {
  // REGISTERS
#define print_register(X)                                                      \
  CharBuffer_append_string(&screen_buffer, " " #X ": ");                       \
  CharBuffer_append_hex(&screen_buffer, machine->X);
  print_register(PC);
  print_register(SP);
  print_register(DT);
  print_register(ST);
  print_register(I);
  CharBuffer_append_string(&screen_buffer, "\n");
  for (int i = 0; i < 16; i++) {
    CharBuffer_append_string(&screen_buffer, " V");
    CharBuffer_append_text(&screen_buffer, digits + i, 1);
    CharBuffer_append_string(&screen_buffer, ": ");
    CharBuffer_append_hex(&screen_buffer, machine->V[i]);
  }
  CharBuffer_append_string(&screen_buffer, "\n\n");

#undef print_register
#define ANSI_COLOR_RESET "\x1b[0m"

#define FORGROUND "\x1b[38;5;"
#define BACKGROUND "\x1b[48;5;"
  // MEMORY AROUND PC
  const int range = 4;
  for (int i = max(0, machine->PC - range);
       i < min(machine->PC + range + 1, RAM_SIZE); i++) {

    if (i == machine->PC) {
      CharBuffer_append_string(&screen_buffer,
                               BACKGROUND "210m" FORGROUND "130m");
    }

    CharBuffer_append_hex(&screen_buffer, i);
    CharBuffer_append_string(&screen_buffer, ": ");
    CharBuffer_append_hex(&screen_buffer, machine->RAM[i]);
    CharBuffer_append_string(&screen_buffer, "\n");

    if (i == machine->PC) {
      CharBuffer_append_string(&screen_buffer, ANSI_COLOR_RESET);
    }
  }

  // STACK

  // KEYBOARD STATE
  CharBuffer_append_string(&screen_buffer, "\n\n");
  for (int i = 0; i < 16; i++) {
    CharBuffer_append_string(&screen_buffer, " K");
    CharBuffer_append_text(&screen_buffer, digits + i, 1);
    CharBuffer_append_string(&screen_buffer, ": ");
    CharBuffer_append_hex(&screen_buffer, machine->keyboard[i]);
  }

  write(STDOUT_FILENO, screen_buffer.buf, screen_buffer.len);

  screen_buffer.len = 0;
}
