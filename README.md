# TriAevum OOT3d for the PlayStation 5

A patch set that ports [TriAevum](https://github.com/coccofresco/TriAevum) (the AOT-recompiled Ocarina of Time 3D with its own Vulkan PICA renderer) to the PlayStation 5. The game runs as a statically linked in-process title (`oot3d_native_game` target), producing a single `eboot.bin`. Vulkan rendering goes through RADV. This port reuses the PS5 platform layer, SDK toolchain, and Vulkan driver from the [WWHD PS5 port](https://github.com/griches/PS5_WindWakerHD).

Licensed under GPL-3.0. This is a bring-your-own and build-your-own kit (You supply the ROM and build the binary yourself). 
eboot.bin contains Nintendo-derived translated code and cannot be shared. The AOT translation step requires a legitimate dump of the EU version of OoT3DS (title ID 0004000000033500, ver 1.4 rev1) — the translator’s symbol table and shard layout are specific to that release.

### Patches created for this port

All patches apply to the TriAevum beta.1.1 source tree (`b20ff67`):

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

Prerequisites (WSL, once):
sudo apt install clang lld cmake ninja-build git python3 libclang-rt-dev unzip curl
cmake --version   # must be >= 3.30

Download and extract TriAevum-v0.8.0-beta.1.1-Windows-x64.zip from https://github.com/coccofresco/TriAevum/releases/tag/v0.8.0-beta.1.1
Navigate inside the folder TriAevum-v0.8.0-beta.1.1-Windows-x64/
Run TriAevumForge.exe and point it at your decrypted EUR ROM (.3ds or .cci, title ID 0004000000033500, v1.4 rev1). Click on 'Prepare and install'.
<img width="950" height="568" alt="image" src="https://github.com/user-attachments/assets/020c0d5a-1b2a-474d-915a-060b3a77c018" />
Let Forge finish - it will produce the translated title source under data/titles/oot3d-eur-catalogue...

From the TriAevum-v0.8.0-beta.1.1-Windows-x64/ folder run under WSL:
unzip -o source/TriAevum-source.zip -d source
unzip -o source/titles/oot3d-eur-project-baseline-16a6b0aa-translated.zip -d source/titles/oot3d-eur-translated
TITLES=$(dirname "$(find source/titles/oot3d-eur-translated -name TITLE_SOURCE_MANIFEST.json | head -1)")

git clone https://github.com/rimidalv333/erebus-TriAevum.git
export R="$(pwd)/erebus-TriAevum/triaevum-ps5"
chmod +x "$R"/ps5/*.sh

cd source
git init -q
git apply --ignore-whitespace "$R/triaevum-ps5-runtime-combined.patch"
cd ..

"$R/ps5/build-ps5.sh" "$R/kit" "source" "$TITLES" "ps5-work" 2>&1 | tee build.log
(If any failures occur during build like crashing while optimizing one SPIRV-Tools file, rerun the build)
(If failures during build continue *add specification to what the segmentation faults are* try downgrading llvm
sudo apt install clang-19 lld-19 llvm-19 libclang-rt-19-dev
export LLVM_CONFIG=/usr/bin/llvm-config-19
"$R/kit/sdk/bin/prospero-llvm-config" --version)

<img width="1920" height="1080" alt="Screenshot 2026-10-20 00-47-13" src="https://github.com/user-attachments/assets/0330305b-8285-4a13-9d26-05fb06a9e6ac" />
<img width="1920" height="1080" alt="Screenshot 2026-10-20 00-48-24" src="https://github.com/user-attachments/assets/d2a012d3-0c16-45ea-a8be-826ff48ff394" />
<img width="1920" height="1080" alt="Screenshot 2026-10-20 00-48-50" src="https://github.com/user-attachments/assets/593fc0a7-8088-4371-858a-31902c07955b" />

