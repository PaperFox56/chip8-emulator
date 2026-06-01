#ifndef CHIP8_DEBUGGER_H
#define CHIP8_DEBUGGER_H

#include "cpu.h"

/*
 * This function will contain all the initialisation needed fro the debugger.
 *
 * @param machine: An optional pointer to an existing Chip8 state. If not
 * provided, the debugger will create a new machine.
 * @return A pointer to the Chip8 state.
 * */
Chip8 *Chip8_Debuger_init(Chip8 *machine);

#endif
