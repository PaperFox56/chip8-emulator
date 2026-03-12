#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include <teye/teye.h>

#include "cpu.h"
#include "timer.h"

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

  TEYE_Buffer framebuffer = {0};
  TEYE_allocate_buffer(&framebuffer, SCREEN_WIDTH, SCREEN_WIDTH);

  time_t previous_frame = currentTimeMillis();
  time_t frame_rate = 60;
  time_t cpu_frequency = 500;

  while (running) {

    for (int i = 0; i < cpu_frequency / frame_rate; i++) {
      Chip8_step_through(machine);
    }

    // We need to convert the chip8's framebuffer to a proper TEYE buffer
    for (int i = 0; i < SCREEN_HEIGHT; i++) {
      for (int j = 0; j < SCREEN_WIDTH; j++) {
        framebuffer.buffer[i * SCREEN_WIDTH + j] =
            (machine->framebuffer[i] >> (63 - j)) & 1;
      }
    }

    TEYE_blit(framebuffer, FitWidth, 0, 0, 1, 1);
    TEYE_render_frame();

    time_t current = currentTimeMillis();
    time_t delta_time = current - previous_frame;
    previous_frame = current;

    sleep_ms(1000 / frame_rate - delta_time);

    printf("%ld", delta_time);
  }

  TEYE_free_buffer(&framebuffer);
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
