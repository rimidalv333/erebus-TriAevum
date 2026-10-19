# TriAevum for the PlayStation 5

A patch set that ports [TriAevum](https://github.com/nicbarker/triaevum) (the AOT-recompiled Ocarina of Time 3D with its own Vulkan PICA renderer) to the PlayStation 5. The game runs as a statically linked in-process title (`oot3d_native_game` target), producing a single `eboot.bin`. Vulkan rendering goes through RADV. This port reuses the PS5 platform layer, SDK toolchain, and Vulkan driver from the WWHD PS5 port.

Licensed under GPL-3.0-or-later, matching TriAevAum's own license. The output `eboot.bin` contains Nintendo-derived translated code and must not be shared.

---

## Components and where they come from

### From TriAevum (upstream, unmodified)

- **TriAevum beta.1.1 source** (commit `b20ff67`): the full source tree. All patches in this port apply on top of it. Available from TriAevum's own repository.

### From the WWHD PS5 port kit (`triaevum-ps5.tar.gz`)

> *You will provide these in the repo. Listed here for completeness.*

- `ps5/` build scripts: `build-ps5.sh`, `build-deps.sh`, `build-sdl.sh`, `build-shaderc.sh`, `configure-host.sh`, `toolchain.cmake`, `project-include.cmake`
- `ps5/platform/`: `startup.c` (constructor that sets up `/app0` paths, reads `env.txt`, redirects stderr to klog), `platform.c`, `platform.h`, `shims.c`
- `ps5/sdl2/`: SDL2 PS5 backend (`SDL_ps5video.c` and related files) and `sdl2-core.patch`
- `ps5/vulkan-shim/`: `gen_vk_shim.py` - generates a static Vulkan loader shim since the PS5 has no system Vulkan loader; every `vk*` call forwards to RADV
- `ps5/sce_sys/`: console metadata (param.json, icon, etc.)
- `ps5/tools/`: native tool build helpers
- The SDK kit itself (`kit/`): `sdk/` (prospero-clang, linker, headers) and `vulkan/` (RADV archive, native tool source)

### From Henriko (optional texture pack)

- **Henriko Maggioni's OoT3D 4K texture pack**: Azahar-format replacement textures. Placed under `/app0/triaevum/textures/` on the console. Available from Henriko's distribution page. The textures use the naming convention `tex1_WxH_HASH_fmt_mipN.png`.

### Patches created for this port

All patches apply to the TriAevum beta.1.1 source tree (`b20ff67`):

| Patch | Target |
|---|---|
| `triaevum-ps5-runtime.patch` | CMake build system, dependency wiring, PS5 platform glue |
| `triaevum-ps5-nosafepresentation.patch` | Safe-presentation launch marker bypass |
| `triaevum-ps5-fadefix.patch` | PICA composition fade-to-black fix |
| `triaevum-ps5-texarena.patch` | Texture upload arena overflow fix (part 1) |
| `triaevum-ps5-texarena2.patch` | Texture upload arena overflow fix (part 2) |

---

## Revision history

### Build 1 - Initial boot
First successful boot on the PS5. Display and controls worked, but several issues were present with the pipeline cache, shader cache paths, and the safe-presentation launch marker.

### Build 2 - Pipeline and shader cache disabled
The Vulkan pipeline cache caused hangs on cold boot. Disabled via `VK_DISABLE_PIPELINE_CACHE=1` in `env.txt`. MESA shader cache was also disabled (`MESA_SHADER_CACHE_DISABLE=true`) to avoid path issues. The game now booted reliably with kill-and-relaunch.

### Build 3 - Config and path corrections (`TriAevum.json`)
Corrected the runtime configuration: set window to 1920x1080, render scale 1.0, AA off, NIS upscaler, Original30 frame rate, SurfaceLighting Native, window position 0,0. Removed `null` array values that caused parse failures. All effects (shadows, AO, GI, reflections) set to Off for a stable baseline.

### Build 4 - Safe-presentation bypass (`nosafepresentation.patch`)
TriAevum's safe-presentation mechanism writes a launch marker that lives for 60 seconds. If the game exits sooner (e.g. a crash), the next launch resets display settings to 1280x720 windowed, breaking the UI on the PS5's fixed output. The patch disables this marker entirely so relaunches always use the config as written.

### Build 5 - Fade-to-black box fix (`fadefix.patch`)
The PICA composition resolver required a scene to have drawn on the color target before it would classify a whole-target UI wash as a screen-level fade. Solid fades over loading screens (untextured geometry covering the viewport) appeared as a small rectangle in the top-left instead of covering the full frame. The fix allows untextured whole-target washes to be promoted to screen-level regardless of whether a scene has drawn yet.

### Build 6 - Grass far-tufts disabled
The grass system's "far tufts" (billboard-style distant grass clumps) disappeared at close range and reappeared at distance, creating a visible pop-in ring around the player. Disabling `FarTuftsEnabled` in the config eliminated the artifact. The `DrawDistance` and instance budget remain at their high custom values (50000 / 500k).

### Build 7 - Texture arena overflow fix, part 1 (`texarena.patch`)
With the Henriko 4K texture pack enabled, entering interior rooms (e.g. the Kakariko house) crashed with "per-frame vertex arena exhausted". The replacement textures are far larger than native ones, and many load in a single frame. The original code uploaded textures into a shared 64 MB per-frame vertex arena, which overflowed. The patch adds a fallback: when a texture upload would not fit in the arena, it allocates a dedicated staging buffer that is released when the frame slot is reused.

### Build 8 - Texture arena overflow fix, part 2 (`texarena2.patch`)
Even with the fallback in place, textures could still fill the arena nearly to its 64 MB limit before any single upload triggered the fallback, leaving no room for subsequent geometry and UI draws (which also use the arena and abort if it's full). The fix caps texture uploads at half of the arena (32 MB), sending everything beyond that to dedicated staging buffers. This ensures at least 32 MB remains for geometry and UI in every frame.

---

## Prerequisites

All work is done on **Windows with WSL2** (Ubuntu recommended). You need the following installed inside WSL:

- **clang 18+** with **lld** (the linker)
  ```bash
  sudo apt install clang-18 lld-18 libclang-rt-18-dev
  ```
- **CMake >= 3.30**
  ```bash
  # If your distro's cmake is older:
  pip3 install cmake --break-system-packages
  ```
- **Ninja**
  ```bash
  sudo apt install ninja-build
  ```
- **Git**
  ```bash
  sudo apt install git
  ```
- **Python 3** (for the Vulkan shim generator and build scripts)
  ```bash
  sudo apt install python3
  ```
- **zlib development headers** (for the native tool)
  ```bash
  sudo apt install zlib1g-dev
  ```
- **compiler-rt builtins** (`libclang-rt-dev` or `libclang-rt-18-dev` depending on distro)

Make sure `clang-18`, `clang++-18`, and `ld.lld-18` are in your PATH, or symlink them:
```bash
sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-18 100
sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-18 100
sudo update-alternatives --install /usr/bin/ld.lld ld.lld /usr/bin/ld.lld-18 100
```

---

## Directory layout (on your Windows machine)

All paths below assume you work from a drive accessible in WSL. Replace `D:` with your drive letter.

```
D:\triaevum-ps5\
  kit\                      # the PS5 SDK kit
    sdk\                    # prospero-clang, headers, linker
    vulkan\                 # RADV archive, native tool source
  source\                   # TriAevum beta.1.1 source (b20ff67), patched
  titles\                   # translated title source (the 256 shard .cpp files)
  ps5-work\                 # build output (created automatically)
  triaevum-ps5\             # this repo (build scripts, patches, configs)
    ps5\
      build-ps5.sh
      ...
    patches\
      triaevum-ps5-runtime.patch
      triaevum-ps5-nosafepresentation.patch
      triaevum-ps5-fadefix.patch
      triaevum-ps5-texarena.patch
      triaevum-ps5-texarena2.patch
    configs\
      TriAevum.json
      env.txt
```

In WSL, these paths are accessible under `/mnt/d/triaevum-ps5/`.

---

## Step-by-step build guide

Download and extract TriAevum-v0.8.0-beta.1.1-Windows-x64.zip from https://github.com/coccofresco/TriAevum/releases/tag/v0.8.0-beta.1.1
Navigate inside the folder TriAevum-v0.8.0-beta.1.1-Windows-x64/
Run TriAevumForge.exe and point it at your decrypted EUR ROM (.3ds or .cci, title ID 0004000000033500, v1.4 rev1). Click on 'Prepare and install'.
<img width="950" height="568" alt="image" src="https://github.com/user-attachments/assets/020c0d5a-1b2a-474d-915a-060b3a77c018" />
Let Forge finish - it will produce the translated title source under data/titles/oot3d-eur-catalogue...

From the TriAevum-v0.8.0-beta.1.1-Windows-x64/ folder run under WSL:

unzip source/TriAevum-source.zip -d source
git clone https://github.com/rimidalv333/erebus-TriAevum.git
export R="$(pwd)/erebus-TriAevum/triaevum-ps5"

cd source
git init
git apply --ignore-whitespace "$R/triaevum-ps5-runtime.patch"
cd ..

TITLES=$(ls -d data/titles/oot3d-eur-catalogue-*/*/ | head -1)
"$R/ps5/build-ps5.sh" "$R/kit" "source" "$TITLES" "ps5-work" 2>&1 | tee build.log
