#include "timer.h"

#ifdef _WIN32
#include <windows.h>
#else

#define _POSIX_C_SOURCE 199309L

#include <sys/time.h>
#include <time.h>
#include <unistd.h>
#endif

long currentTimeMillis() {
#ifdef _WIN32
  // Windows Monotonic Timer
  LARGE_INTEGER freq, count;
  QueryPerformanceFrequency(&freq);
  QueryPerformanceCounter(&count);
  return (long)((count.QuadPart * 1000) / freq.QuadPart);
#elif defined(_POSIX_TIMERS) && _POSIX_TIMERS > 0
  // POSIX Monotonic Timer (Preferred)
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (long)ts.tv_sec * 1000 + (ts.tv_nsec / 1000000);
#else
  // Fallback to Wall-clock (Legacy POSIX)
  struct timeval tv;
  gettimeofday(&tv, NULL);
  return (long)tv.tv_sec * 1000 + (tv.tv_usec / 1000);
#endif
}

void sleep_ms(int milliseconds) {
#ifdef _WIN32
  Sleep(milliseconds);
#elif _POSIX_C_SOURCE >= 199309L
  struct timespec ts = {milliseconds / 1000, (milliseconds % 1000) * 1000000};
  nanosleep(&ts, NULL);
#else
  usleep(milliseconds * 1000);
#endif
}
