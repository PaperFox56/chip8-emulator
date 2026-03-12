ifneq (,)
This makefile require GNU Make
endif

CC=gcc
CFLAGS= -Wall -Wextra -pedantic -std=c99 -fsanitize=address

TARGET=chip8emu
SRCS    := $(wildcard src/*.c)
OBJS   := $(SRCS:src/%.c=bin/%.o)

DEPS     := $(OBJECTS:.o=.d)


.PHONY: all 4(TARGET) clean

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(OBJS) -o bin/$(TARGET) $(CFLAGS) -l teye

bin/%.o: ./src/%.c	
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

#%.o: ./bin/%.o

-include $(DEPS)

clean:
	rm -r bin
