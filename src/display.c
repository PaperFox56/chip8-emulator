#include <stdlib.h>
#include <teye/teye.h>
#include <unistd.h>

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

void Display_update(Chip8 *machine) {
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

  CharBuffer_append_cursor_move(&screen_buffer, teye_frame_buffer.height + 1,
                                0);

  write(STDOUT_FILENO, screen_buffer.buf, screen_buffer.len);
}
