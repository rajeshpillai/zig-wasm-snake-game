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
