#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <teye/teye.h>

#include "common.h"
#include "cpu.h"
#include "debugger.h"

int main() {

  Chip8 *machine = Chip8_Debugger_init(NULL);
  // TODO: let the caller chose the ROM to load
  if (Chip8_Debugger_load_ROM("testROMs/test_opcode.ch8") != EXIT_SUCCESS) {
    free(machine);
    return EXIT_FAILURE;
  }

  Chip8_Debugger_mainloop();
  Chip8_Debugger_quit();

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
    fprintf(stderr,
            "load_ROM_from_file_path: Couldn't open ROM file '%s': ", path);
    perror("");
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
