#!/bin/bash

# Build Snake Game WASM
zig build-exe src/main.zig \
  -target wasm32-freestanding \
  --import-memory \
  -fno-entry \
  --export=init \
  --export=update \
  --export=setDirection \
  --export=getBufferPtr \
  --export=getBufferSize \
  --export=drawGrid \
  --export=getScore \
  --export=isGameOver \
  -O ReleaseSmall \
  -femit-bin=public/snake.wasm

echo "✅ Snake WASM built successfully: public/snake.wasm"
