# Credits

## PS5_WindWakerHD — griches / Mihawk

https://github.com/griches/PS5_WindWakerHD

The platform layer, build toolchain, and prebuilt kit that this port is built on top of.

**`ps5/platform/`** (`platform.c`, `platform.h`, `startup.c`, `shims.c`) — klog output, shell splash dismissal, pad input, audio, and the title's startup constructor. Adapted from PS5_WindWakerHD. MIT.

**`ps5/sdl2/`** (`SDL_ps5video.c`, `SDL_ps5audio.c`, `SDL_ps5joystick.c`) — SDL2 platform backend for the console: single display/window, audio output, DualSense input mapped to SDL joystick events. Adapted from PS5_WindWakerHD. MIT.

**`ps5/sdl2-core.patch`** — patch to SDL2 core enabling the PS5 backend to be selected at build time. From PS5_WindWakerHD.

**`ps5/toolchain.cmake`**, **`ps5/tools/`**, **`ps5/vulkan-shim/`** — CMake cross-compilation toolchain file for prospero-clang, linker script wrapper, and Vulkan loader shim generator. From PS5_WindWakerHD.

**`kit/sdk/`** — LLVM/Clang/lld toolchain from the public [PS5 payload SDK](https://github.com/ps5-payload-dev/sdk), via PS5_WindWakerHD's fork. GPL-3.0-or-later.

**`kit/vulkan/`** — RADV Vulkan driver and `libc.prx` runtime shim. GPL-3.0-or-later. See `kit/vulkan/LICENSE` and `kit/vulkan/NOTICE.md` for the full dependency and license breakdown.

**`kit/lib/`** — prebuilt static archives (`libps5_platform.a`, `libcemu_latte.a`, `libimgui.a`, `libSDL3.a`) built from PS5_WindWakerHD's dependencies. GPL-3.0-or-later / zlib (SDL3).

---

## TriAevum — nicbarker

https://github.com/nicbarker/triaevum

The upstream project this port targets. AOT-recompiled Ocarina of Time 3D with a Vulkan PICA renderer. GPL-3.0-or-later. This repo contains no TriAevum source — only patches that apply on top of commit `b20ff67` (beta.1.1).

---

## Henriko Maggioni — texture pack (optional)

4K Azahar-format texture pack for OoT3D. Not included in this repo; bring your own copy. Textures go into `/app0/triaevum/textures/` on the console.
