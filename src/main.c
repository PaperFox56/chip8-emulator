#include <signal.h>
#include <stdio.h>
#include <stdlib.h>

#include <teye/teye.h>

#include "cpu.h"

#define min(a, b) (a < b ? a : b)

volatile int running = 1;

void signal_handler() { running = 0; }

int loadROM(uint8_t *mem, int start, int size, const char *path);

int main() {

  signal(SIGINT, signal_handler);

  TEYE_init();
  atexit(TEYE_free);

  Chip8 *machine = (Chip8 *)malloc(sizeof(Chip8));
  Chip8_init(machine);

  if (loadROM(machine->RAM + 0x200, 0, RAM_SIZE - 0x200,
              "testROMs/test_opcode.ch8") != EXIT_SUCCESS) {
    running = 0;
    perror("Couldn't load the test ROM");
  }

  // There is no way this is gonna backfire right ?
  // Anyways, don't call any memory management function on this buffer.
  TEYE_Buffer framebuffer = {SCREEN_WIDTH, SCREEN_HEIGHT, machine->framebuffer,
                             SCREEN_PIXEL_COUNT};

  while (running) {
    Chip8_step_through(machine);

    TEYE_blit(framebuffer, FitWidth, 0, 0, 1, 1);
    TEYE_render_frame();
  }

  printf("Come on, do something!");

  free(machine);

  return 0;
}

int loadROM(uint8_t *mem, int start, int size, const char *path) {
  // open the file in read binary mode
  FILE *file = fopen(path, "rb");

  if (file == NULL) {
    printf("Error: Couldn't open ROM file <%s>\n", path);
    return EXIT_FAILURE; // Indicate an error
  }

  fseek(file, 0, SEEK_END); // Move the file pointer to the end of the file
  long length =
      ftell(file); // Get the current position (which is the file's size)
  rewind(file);

  if (length > start) {
    fseek(file, start, 0);
    fread(mem, 1, min(length - 1, size), file);
  }

  fclose(file);

  return EXIT_SUCCESS;
}
