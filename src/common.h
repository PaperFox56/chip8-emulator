#ifndef CHIP_UTILS_H
#define CHIP_UTILS_H

#include <stdint.h>
#include <stdio.h>

#define min(a, b) (a < b ? a : b)

/** utils.h
 *
 * This file defines useful, implementation depentent functions that are used by
 * the debugger. Each of these functions have to implemented somewhere. Most
 * will be in main.c
 */

/**
 * Read bytes from a file descriptor and put the content in the given buffer.
 * This function will not overflow the buffer. It will abort if there too much
 * data to be loaded big to be loaded.
 *
 * @param mem: A pointer to the buffer.
 * @param start: An offset in the file indicating where the copy should start.
 * @param size: The size of the buffer.
 * @param file: The file descriptor.
 *
 * @return EXIT_FAILURE if an error occured, EXIT_SUCCESS otherwise.
 */
int load_ROM_from_file_descriptor(uint8_t *mem, unsigned int start,
                                  unsigned int size, FILE *file);
/**
 * Opens a binary file and calls `load_ROM_from_file_descriptor` to load the
 * data into the given buffer.
 *
 * @param mem: A pointer to the buffer.
 * @param start: An offset in the file indicating where the copy should start.
 * @param size: The size of the buffer.
 * @param path: A path to the file to be loaded.
 *
 * @return EXIT_FAILURE if an error occured, EXIT_SUCCESS otherwise.
 */
int load_ROM_from_file_path(uint8_t *mem, unsigned int start, unsigned int size,
                            const char *path);

void CharBuffer_append_hex(struct CharBuffer *char_buffer, unsigned int num,
                           unsigned int min_pecision);

void CharBuffer_append_string(struct CharBuffer *charbuffer, const char *s);

#endif
