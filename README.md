Chemuz is a basic Chip8 emulator with a integreted debugger. It was originally a port of a old project made in C but then I improved it and added a proper GUI.

# GUI 

The GUI of the debugger uses [raylib](https://github.com/raysan5/raylib) and [raygui](https://github.com/raysan5/raygui) as front end and nfd for the file dialogue.

# Features

## Already implemented 

- Screen (of course)
- Live desassembly panel
- Registers panel allowing to directly inject values into any register
- Ablity to load ROM files form disk

## In planning
- add breakpoints
- Implement scrolling inside the disassembly panel
- Memory panel allowing to see and manipulate the machine's RAM
- State saving and loading
- Rewinding to a previous state (not to sure about that one but I'll try)

# Keymap

 - Press `Space` to pause or resume the emulator. 
 - The 16 keys of the Chip8 are mapped by default onto the following keybord keys:

`0` -> `Z`
`1` -> `X`
`2` -> `C`
`3` -> `V`
`4` -> `A`
`5` -> `S`
`6` -> `D`
`7` -> `F`
`8` -> `Q`
`9` -> `W`
`A` -> `E`
`B` -> `R`
`C` -> `1`
`D` -> `2`
`E` -> `3`
`F` -> `4`

Why those? Because I don't have a numerical pad, but feel free to remap it as you want in [the configs file](src/gui/configs.zig).


# Build and run the project

The whole project is made in Zig so all you have to to is install zig on you device, clone this repository:

```bash
clone https://github.com/PaperFox56/chip8-emulator
```

and call 
```zig
zig build run
```