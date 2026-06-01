#ifndef TERMINAL_H
#define TERMINAL_H

#ifdef __cplusplus
extern "C" {
#endif

int get_window_size(int *rows, int *cols);

//
int enable_raw_mode();
void disable_raw_mode();

#ifdef __cplusplus
}
#endif
#endif
