#include <stdio.h>
#include <stdlib.h>

#include "common.h"
#include "cpu.h"
#include "debugger.h"

static Chip8 *machine;

Chip8 *Chip8_Debuger_init(Chip8 *_machine) {
  if (machine == NULL) {
    machine = (Chip8 *)malloc(sizeof(Chip8));
    Chip8_init(machine);
  } else {
    machine = _machine;
  }

  return machine;
}

int Chip8_Debugger_load_ROM(const char *path) {
  if (load_ROM_from_file_path(machine->RAM + 0x200, 0, RAM_SIZE - 0x200,
                              path) != EXIT_SUCCESS) {
    fprintf(stderr,
            "Chip8_Debugger_load_ROM: Couldn't load the ROM in file <%s>\n",
            path);
  }

  return EXIT_SUCCESS;
}
