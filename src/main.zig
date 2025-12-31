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

// Initializes the game state: resets snake, score, and spawns first food.
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

// Draws the background grid to the pixel buffer to help visualize the play area
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

// Updates the snake's direction based on user input (0=UP, 1=RIGHT, 2=DOWN, 3=LEFT)
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

// Core game loop: updates position, checks collisions, handles eating, and triggers rendering.
// Returns false if the game is over.
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

// Places food at a random Grid coordinate
fn spawnFood() void {
    const random = prng.random();
    food.x = random.intRangeLessThan(i32, 0, GridSize);
    food.y = random.intRangeLessThan(i32, 0, GridSize);
}
