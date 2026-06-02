#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <teye/char_buffer.h>
#include <time.h>
#include <unistd.h>

#include "common.h"
#include "cpu.h"
#include "debugger.h"
#include "display.h"
#include "terminal/terminal.h"
#include "timer.h"

static const time_t millis_per_frame = 1000 / 60;
static const unsigned int chip8_clock_target_frequency = 600; // In Hz
                                                              //
static Chip8 *machine;

static volatile sig_atomic_t running;

void signal_handler() { running = 0; }

Chip8 *Chip8_Debugger_init(Chip8 *_machine) {
  if (Display_init() != 0) {
    fprintf(stderr,
            "Chip8_Debugger_init: Couldn't initialise the display library");
    return NULL;
  }

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
            "Chip8_Debugger_load_ROM: Couldn't load the ROM in file '%s'\n",
            path);
  }

  return EXIT_SUCCESS;
}

void Chip8_Debugger_mainloop() {
  signal(SIGINT, signal_handler);
  // terminal raw mode
  // enable_raw_mode();

  int paused = 0;
  running = 1;

  time_t previous_frame = currentTimeMillis();
  time_t previous_timer_update = previous_frame;
  time_t previous_cpu_instruction = previous_frame;

  float debugger_speed = .0005;

  /**
   * The CHIP8 specification requires that the timers be uptated at a strict
   * 60Hz frequency. On top of that, the CPU's frequecy is between 500Hz and
   * 700Hz. We also want to be able to modify the emulator's speed so we
   * need a way to control how many instructions and timer updates are done
   * every second.
   *
   * First, we need to calcute how many CPU instructions should be executed
   * between two timer updates. Then, we use the emulator's speed to compute
   * how many times per 'real' seconds the timers have to be updated.
   *
   * Then, we can just wait for the timer update time, execute the needed
   * number of instructions, and then wait for the next time.
   */
  float real_timer_delay = 1000 / (debugger_speed * 60); // ms
  float real_cpu_delay =
      1000 / (debugger_speed * chip8_clock_target_frequency); // ms

  while (running) {
    time_t current_time = currentTimeMillis();
    time_t display_delta = current_time - previous_frame;
    time_t timer_delta = current_time - previous_timer_update;
    time_t cpu_delta = current_time - previous_cpu_instruction;

    if (display_delta >= millis_per_frame) {
      previous_frame = current_time;
      Display_update(machine);
      display_debugging_information(machine);
    } else {
    }

    if (cpu_delta >= real_cpu_delay) {
      previous_cpu_instruction = current_time;
      Chip8_step_through(machine);
    }
    if (timer_delta >= real_timer_delay) {
      previous_timer_update = current_time;
      // Update timers
      if (machine->DT > 0)
        machine->DT--;
      if (machine->ST > 0)
        machine->ST--;
    }
  }

  // disable_raw_mode();
}

void Chip8_Debugger_quit() {}
