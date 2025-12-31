# Step-by-Step: Building a Classic Snake Game with Zig and WASM

This tutorial provides a complete, beginner-friendly guide to building a high-performance Snake game. You will learn how to handle game logic, state, and pixel-level rendering entirely in **Zig**, using **Shared Memory** to display the results in the browser.

---

## Step 1: Initialize the Project Folders
Set up the directory structure for your game:

```bash
mkdir -p classic-snake-game/src classic-snake-game/public
cd classic-snake-game
```

You can refer the HTML and CSS from the github repo.

---

## Step 2: Create the Build Script
Create a file named `build.sh` in the `classic-snake-game/` folder. This script tells the Zig compiler how to package our code into a WebAssembly module.

```bash
#!/bin/bash

# Compile Zig to WebAssembly
zig build-exe src/main.zig \
  -target wasm32-freestanding \
  --import-memory \
  -fno-entry \
  --export=init \
  --export=update \
  --export=setDirection \
  --export=getBufferPtr \
  --export=getBufferSize \
  --export=getScore \
  --export=isGameOver \
  --export=drawGrid \
  -O ReleaseSmall \
  -femit-bin=public/snake.wasm

echo "✅ Snake WASM built successfully: public/snake.wasm"
```

**Make it executable:**
```bash
chmod +x build.sh
```

---

## Step 3: Implement the Game Engine (Zig)
Create `src/main.zig`. This is where all the game logic and pixel rendering happens. We will implement the snake movement, collision detection, and a grid drawing feature.

```zig
const std = @import("std");

var allocator = std.heap.wasm_allocator;

const GridSize = 20;
const CellSize = 20; // Pixels per cell
const Width = GridSize * CellSize;  // Width of the playing area
const Height = GridSize * CellSize; // Height of the playing area

// Direction enum -> I know these comments are sometimes useless, but I like them
const Direction = enum(u8) {
    up = 0,
    right = 1,
    down = 2,
    left = 3,
};

// This structure is used to represent, snake & food.
const Point = struct {
    x: i32,
    y: i32,
};

var snake: [400]Point = undefined; // Array to store snake's body segments (400 is currently hardcoded -> (in html/js as well))
var snake_len: usize = 3;
var direction: Direction = .right;
var food: Point = .{ .x = 10, .y = 10 };
var pixel_buffer: []u8 = &[_]u8{};
var score: u32 = 0;
var game_over: bool = false;


// PUBLIC FUNCTIONS (exported) -> These functions will be available to Browser/JS
pub export fn init() void {
    snake_len = 3;
    snake[0] = .{ .x = 5, .y = 5 };
    snake[1] = .{ .x = 4, .y = 5 };
    snake[2] = .{ .x = 3, .y = 5 };
    direction = .right;
    score = 0;
    game_over = false;
    spawnFood();

    if (pixel_buffer.len == 0) {
        pixel_buffer = allocator.alloc(u8, Width * Height * 4) catch unreachable;
    }
    @memset(pixel_buffer, 0);
}

pub export fn drawGrid() void {
    // Draw vertical and horizontal lines by iterating through the canvas
    // in steps of CellSize. We use 1px thick rectangles for the lines
    // with a subtle greenish-gray color (30, 40, 30) to match the theme.
    var x: i32 = 0;
    while (x < Width) : (x += CellSize) {
        drawRect(x, 0, 1, Height, 30, 40, 30);
    }
    var y: i32 = 0;
    while (y < Height) : (y += CellSize) {
        drawRect(0, y, Width, 1, 30, 40, 30);
    }
}


pub export fn setDirection(dir: u8) void {
    const new_dir: Direction = @enumFromInt(dir);
    // Prevent 180 degree turns, i.e. if the snake is moving UP (0), it cannot suddenly
    // turn DOWN(180) 
    const is_opposite = case: {
        if (direction == .up and new_dir == .down) break :case true;
        if (direction == .down and new_dir == .up) break :case true;
        if (direction == .left and new_dir == .right) break :case true;
        if (direction == .right and new_dir == .left) break :case true;
        break :case false;
    };
    if (!is_opposite) direction = new_dir;
}

pub export fn update() bool {
    if (game_over) return false;

    // Head position
    var head = snake[0];
    switch (direction) {
        .up => head.y -= 1,
        .right => head.x += 1,
        .down => head.y += 1,
        .left => head.x -= 1,
    }

    // Boundary check
    if (head.x < 0 or head.x >= GridSize or head.y < 0 or head.y >= GridSize) {
        game_over = true;
        return false;
    }

    // Self collision (it's not good if the snake collides with itself)
    var i: usize = 0;
    while (i < snake_len) : (i += 1) {
        if (snake[i].x == head.x and snake[i].y == head.y) {
            game_over = true;
            return false;
        }
    }

    // Move body -> this will work, but will be slow
    //i = snake_len;
    //while (i > 0) : (i -= 1) {
    //    snake[i] = snake[i - 1];
    //}

    // This is recommended
    // NOTE: td.mem.copyBackwards is a memory utility function used to copy 
    // elements from a source slice to a destination slice. It is specifically 
    // designed to handle cases where the memory regions overlap and the destination 
    // starts at a higher memory address than the source.

    // Why do we need it?
    // When you move data within the same array, a standard "forward" copy can 
    // accidentally overwrite the data you haven't copied yet.
    
    std.mem.copyBackwards(Point, snake[1..snake_len + 1], snake[0..snake_len]);
    snake[0] = head;

    // Food check
    if (head.x == food.x and head.y == food.y) {
        snake_len += 1;
        score += 10;
        spawnFood();
    }

    render();
    return true;
}


pub export fn getBufferPtr() [*]u8 {
    return pixel_buffer.ptr;
}

pub export fn getBufferSize() usize {
    return pixel_buffer.len;
}

pub export fn getScore() u32 {
    return score;
}

pub export fn isGameOver() bool {
    return game_over;
}



// PRIVATE FUNCTIONS (not exported) 

// Draws a rectangle at the specified position with the specified color
fn drawRect(x: i32, y: i32, width: i32, height: i32, r: u8, g: u8, b: u8) void {
    var py = y;
    while (py < y + height) : (py += 1) {
        var px = x;
        while (px < x + width) : (px += 1) {
            if (px >= 0 and px < Width and py >= 0 and py < Height) {
                const idx = (@as(usize, @intCast(py)) * Width + @as(usize, @intCast(px))) * 4;
                pixel_buffer[idx] = r;
                pixel_buffer[idx + 1] = g;
                pixel_buffer[idx + 2] = b;
                pixel_buffer[idx + 3] = 255;
            }
        }
    }
}

// Renders the game object state to the screen
fn render() void {
    // Clear screen to dark green
    var i: usize = 0;
    while (i < pixel_buffer.len) : (i += 4) {
        pixel_buffer[i] = 10;
        pixel_buffer[i + 1] = 20;
        pixel_buffer[i + 2] = 10;
        pixel_buffer[i + 3] = 255;
    }

    // Draw snake
    var j: usize = 0;
    while (j < snake_len) : (j += 1) {
        const r: u8 = if (j == 0) 100 else 50;
        const g: u8 = if (j == 0) 255 else 200;
        drawRect(snake[j].x * CellSize, snake[j].y * CellSize, CellSize - 1, CellSize - 1, r, g, 50);
    }

    // Draw food
    drawRect(food.x * CellSize, food.y * CellSize, CellSize - 1, CellSize - 1, 255, 50, 50);
}


// PRNG state 
// var prng_state: u64 = 12345; 
var prng: std.Random.DefaultPrng = std.Random.DefaultPrng.init(12345);

fn spawnFood() void {
    const random = prng.random();
    food.x = random.intRangeLessThan(i32, 0, GridSize);
    food.y = random.intRangeLessThan(i32, 0, GridSize);
}
```

### 🧠 How Rendering Works (The "Magic")
You might notice we aren't calling any canvas drawing functions like `fillRect` in Zig. Instead, we are acting as a **software graphics card**.
- `pixel_buffer` is a simple 1D array of bytes representing pixels (`R, G, B, A`).
- `drawRect` calculates the exact index of a pixel in this array: `(y * Width + x) * 4`.
  - **Row Offset (`y * Width`)**: Skips `y` full rows to reach the correct vertical line.
  - **Column Offset (`+ x`)**: Moves `x` pixels into that row.
  - **Bytes per Pixel (`* 4`)**: Multiplies by 4 because each pixel takes up 4 bytes (Red, Green, Blue, Alpha).
- We write color values directly to these memory addresses.
- JavaScript later reads this entire array and "blits" it to the screen in one go.

### 🐍 How Snake Movement Works
The movement happens in two simple phases (check the `update` function):
1.  **Shift the Body**: We loop backwards from the tail to the neck. Each segment takes the position of the one in front of it. We use `std.mem.copyBackwards` for this, which is safer and more efficient than a manual loop when shifting overlapping memory.
    ```zig
    // Like a slinky: Segment 3 moves to Segment 2's spot, etc.
    std.mem.copyBackwards(Point, snake[1..snake_len + 1], snake[0..snake_len]);
    ```
2.  **Move the Head**: The head moves one step into the new direction. Since the body segments just vacated the spot behind the head, the neck moves into the old head position, creating the illusion of smooth movement.

---

## Step 4: Create the JavaScript Glue
Create `public/main.js`. This script loads the Wasm module, handles input, and runs the game loop. It also checks if the "Show Grid" checkbox is enabled.

```javascript
let wasm;
let memory;
let ctx;
let lastTime = 0;
let lastTick = 0;
const tickInterval = 150; // Snake speed (ms)

async function init() {
    console.log("Loading Wasm Snake...");

    const response = await fetch('snake.wasm');
    const bytes = await response.arrayBuffer();

    // Grid 20x20 * Cell 20 = 400x400
    // 400 * 400 * 4 bytes = 640KB (~10 pages)
    memory = new WebAssembly.Memory({ initial: 32 });

    const result = await WebAssembly.instantiate(bytes, {
        env: { memory: memory }
    });

    wasm = result.instance.exports;

    const canvas = document.getElementById('gameCanvas');
    canvas.width = 400;
    canvas.height = 400;
    ctx = canvas.getContext('2d');

    window.addEventListener('keydown', handleKey);

    wasm.init();
    requestAnimationFrame(gameLoop);
}

function handleKey(e) {
    const key = e.key.toLowerCase();
    if (key === 'arrowup' || key === 'w') wasm.setDirection(0);
    if (key === 'arrowright' || key === 'd') wasm.setDirection(1);
    if (key === 'arrowdown' || key === 's') wasm.setDirection(2);
    if (key === 'arrowleft' || key === 'a') wasm.setDirection(3);
}

function gameLoop(time) {
    const elapsed = time - lastTick;
    
    if (elapsed > tickInterval) {
        lastTick = time;

        const success = wasm.update();

        if (document.getElementById('showGrid').checked) {
            wasm.drawGrid();
        }

        if (!success && wasm.isGameOver()) {
            document.getElementById('overlay').classList.remove('hidden');
        }

        // Update score
        document.getElementById('scoreValue').textContent = wasm.getScore();

        // Render from Wasm memory
        const ptr = wasm.getBufferPtr();
        const size = wasm.getBufferSize();
        const pixelData = new Uint8ClampedArray(memory.buffer, ptr, size);
        const imageData = new ImageData(pixelData, 400, 400);
        ctx.putImageData(imageData, 0, 0);
    } // End if (elapsed > tickInterval)

    requestAnimationFrame(gameLoop);
}

function resetGame() {
    document.getElementById('overlay').classList.add('hidden');
    wasm.init();
}

init().catch(err => {
    console.error("Failed to load Wasm:", err);
});
```

---

## Step 5: Build and Play
1. **Compile**: Run the build script to generate `public/snake.wasm`.
   ```bash
   ./build.sh
   ```
2. **Serve**: You need a local server to load the Wasm file (due to browser security policies).
   ```bash
   npx serve public
   # OR
   python3 -m http.server -d public 8080
   ```
3. **Open**: Navigate to `http://localhost:3000` (or whichever port your server uses).

---

## Technical Summary
By using Zig to write raw pixel data to a shared WASM memory buffer, we eliminate the need for thousands of JavaScript calls per frame. This makes the game incredibly efficient. The "Show Grid" feature determines how easily we can add new rendering logic in Zig and control it from the frontend!
