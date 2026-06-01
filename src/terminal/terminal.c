#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <termios.h>

#include "terminal.h"

// Save of the original terminal state to be restored at the end of the program
struct termios original_termios_flags;

void disable_raw_mode() {
  if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &original_termios_flags) == -1) {
    perror("disable_raw_mode: tcsetattr failed: ");
  }
}

int enable_raw_mode() {
  struct termios termios_flags;

  // Get the current terminal attributes
  if (tcgetattr(STDIN_FILENO, &termios_flags) == -1) {
    perror("enable_raw_mode: tcsetattr failed: ");
    return EXIT_FAILURE;
  }
  original_termios_flags = termios_flags; // save for latter

  // Make sure the original state of the program is restored at exit
  atexit(disable_raw_mode);

  // Turns off the ECHO feature, canonical mode and various signals from
  // terminal ISIG: Ctrl+C and Ctrl+Z IEXTEN: Ctrl+V and Ctrl+O
  termios_flags.c_lflag &= ~(ECHO | ICANON | ISIG | IEXTEN);

  // Turns off other signals from terminal
  // IXON: Ctrl+S and Ctrl+Q
  // ICRNL: Ctrl+M  (actually activates it)
  // what about the other ones ? who knows !
  termios_flags.c_iflag &= ~(IXON | ICRNL | BRKINT | INPCK | ISTRIP);
  termios_flags.c_cflag |= (CS8);

  // Turns off output processing
  termios_flags.c_oflag &= ~(OPOST);

  // allows us to set a timeout for the read function
  termios_flags.c_cc[VMIN] = 0;
  termios_flags.c_cc[VTIME] = 1;

  if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &termios_flags) == -1) {
    perror("enable_raw_mode: tcsetattr failed: ");
    return EXIT_FAILURE;
  }

  return EXIT_SUCCESS;
}

int get_cursor_position(int *rows, int *cols) {
  // The n command (Device Status Report) can be used to query the terminal for
  // status information. We want to give it an argument of 6 to ask for the
  // cursor position.
  if (write(STDOUT_FILENO, "\x1b[6n", 4) != 4)
    return -1;
  printf("\r\n");

  char buf[32];
  unsigned int i = 0;

  // Read and parse the response
  while (i < sizeof(buf) - 1) {
    if (read(STDIN_FILENO, &buf[i], 1) != 1)
      break;
    if (buf[i] == 'R')
      break;

    i++;
  }
  // set the last byte to 0
  buf[i] = 0;

  if (buf[0] != '\x1b' || buf[1] != '[')
    return -1; // invalid sequence
  if (sscanf(&buf[2], "%d;%d", rows, cols) != 2)
    return -1; // something bad I guess

  return 0;
}

int get_window_size(int *rows, int *cols) {
  struct winsize ws;

  if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == -1 || ws.ws_col == 0) {
    /*
    ioctl() isn’t guaranteed to be able to request the window size on all
    systems, so we are going to provide a fallback method of getting the window
    size. The strategy is to position the cursor at the bottom-right of the
    screen, then use escape sequences that let us query the position of the
    cursor. That tells us how many rows and columns there must be on the screen.

    There is no simple “move the cursor to the bottom-right corner” command.
    We are sending two escape sequences one after the other. The C command
    (Cursor Forward) moves the cursor to the right, and the B command (Cursor
    Down) moves the cursor down. The argument says how much to move it right or
    down by. We use a very large value, 999, which should ensure that the cursor
    reaches the right and bottom edges of the screen.

    The C and B commands are specifically documented to stop the cursor from
    going past the edge of the screen. The reason we don’t use the
    <esc>[999;999H command is that the documentation doesn’t specify what
    happens when you try to move the cursor off-screen.
    */
    if (write(STDOUT_FILENO, "\x1b[999C\x1b[999B", 12) != 12)
      return -1;
    return get_cursor_position(rows, cols);
  } else {
    *cols = ws.ws_col;
    *rows = ws.ws_row;
    return 0;
  }
}
