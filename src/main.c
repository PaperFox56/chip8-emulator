#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include <teye/teye.h>

#include "common.h"
#include "cpu.h"
#include "display.h"
#include "timer.h"

#define min(a, b) (a < b ? a : b)

volatile int running = 1;

void signal_handler() { running = 0; }

int main() {

  signal(SIGINT, signal_handler);

  if (Display_init() != 0) {
    fprintf(stderr, "Couldn't initialise the display library");
    exit(EXIT_FAILURE);
  }

  Chip8 *machine = (Chip8 *)malloc(sizeof(Chip8));
  Chip8_init(machine);

  if (load_ROM_from_file_path(machine->RAM + 0x200, 0,
                              (unsigned int)(RAM_SIZE - 0x200),
                              "testROMs/test_opcode.ch8") != EXIT_SUCCESS) {
    running = 0;
    perror("Couldn't load the test ROM");
  }

  time_t previous_frame = currentTimeMillis();
  time_t frame_rate = 60;
  time_t cpu_frequency = 500;

  while (running) {

    for (int i = 0; i < cpu_frequency / frame_rate; i++) {
      Chip8_step_through(machine);
    }

    Display_update(machine);
    Display_render();

    time_t current = currentTimeMillis();
    time_t delta_time = current - previous_frame;
    previous_frame = current;

    sleep_ms(1000 / frame_rate - delta_time);

    printf("%ld", delta_time);
  }

  free(machine);

  return EXIT_SUCCESS;
}

int load_ROM_from_file_descriptor(uint8_t *mem, unsigned int start,
                                  unsigned int size, FILE *file) {

  fseek(file, 0, SEEK_END); // Move the file pointer to the end of the file
  long length =
      ftell(file); // Get the current position (which is the file's size)
  rewind(file);

  if (length <= start) {
    // Nothing to read
    return EXIT_SUCCESS;
  }

  unsigned int to_read = length - start;

  if (to_read > size) {
    // Buffer overflow
    fprintf(stderr, "load_ROM_from_file_descriptor: Buffer size is less than "
                    "data length\n");
    return EXIT_FAILURE;
  } else {

    fseek(file, start, 0);
    fread(mem, 1, to_read, file);

    return EXIT_SUCCESS;
  }
}

int load_ROM_from_file_path(uint8_t *mem, unsigned int start, unsigned int size,
                            const char *path) {
  // open the file in read binary mode
  FILE *file = fopen(path, "rb");

  if (file == NULL) {
    char message[512];
    snprintf(message, sizeof(message),
             "load_ROM_from_file_path: Couldn't open ROM file <%s>\n", path);
    perror(message);
    return EXIT_FAILURE;
  }

  if (load_ROM_from_file_descriptor(mem, start, size, file) == EXIT_FAILURE) {
    fprintf(stderr,
            "load_ROM_from_file_path: Error while loading the file's data\n");
    fclose(file);
    return EXIT_FAILURE;
  } else {
    fclose(file);
    return EXIT_SUCCESS;
  }
}
