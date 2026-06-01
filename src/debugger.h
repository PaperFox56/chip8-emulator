#ifndef CHIP8_DEBUGGER_H
#define CHIP8_DEBUGGER_H

#include "cpu.h"

/**
 * This function will contain all the initialisation needed fro the debugger.
 *
 * @param machine: An optional pointer to an existing Chip8 state. If not
 * provided, the debugger will create a new machine in the heap.
 *
 * @note The debugger NEVER frees the pointer so it have to be managed entirely
 * by the caller.
 *
 * @return A pointer to the Chip8 state.
 */
Chip8 *Chip8_Debugger_init(Chip8 *machine);

/**
 * @param path: Path to the ROM file
 * @return EXIT_FAILURE if an error occured, EXIT_SUCCESS otherwise
 */
int Chip8_Debugger_load_ROM(const char *path);

void Chip8_Debugger_mainloop();
void Chip8_Debugger_quit();

#endif
