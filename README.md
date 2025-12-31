# Classic Snake - Wasm + HTML5 Canvas

A high-performance implementation of the classic Snake game using Zig and WebAssembly.

## Overview
This demo demonstrates how Zig can handle game logic, state management, and pixel-level rendering, providing a complete frame buffer to JavaScript via shared memory.

## Key Features
- **Grid-based Logic**: 20x20 grid managed entirely in Zig.
- **Pixel Rendering**: Zig draws the snake and food into a raw byte array.
- **Low Latency**: Shared memory ensures zero-copy rendering from Wasm to Canvas.
- **Minimal Footprint**: The compiled WASM is only ~2KB.

## Quick Start

### 1. Build
```bash
./build.sh
```

### 2. Serve
```bash
cd public
python3 -m http.server 8000

OR

npx serve .

```

### 3. Play
Open `http://localhost:8000` and use Arrow Keys or WASD.

## Tech Stack
- **Zig**: Game engine and manual frame buffer rendering.
- **WebAssembly**: The compilation target for the Zig engine.
- **Vanilla JS**: Input handling and Canvas memory mapping.
- **CSS3**: Premium dark-mode UI styling.
