#ifndef CHIP8_DISPLAY_H
#define CHIP8_DISPLAY_H

#include "cpu.h"

#ifdef __cplusplus
extern "C" {
#endif

/** Initialise the rendering system
 * @return 0 if the init was succesful, -1 otherwise
 */
int Display_init();

/**
 * Extract all the neccessary information from the machine to update the screen
 * buffers
 */
void Display_update(Chip8 *machine);
void Display_render();

#ifdef __cplusplus
}
#endif

#endif
