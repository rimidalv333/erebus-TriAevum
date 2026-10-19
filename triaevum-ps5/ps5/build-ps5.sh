#!/usr/bin/env bash
# TriAevum for the PlayStation 5: build the title folder.
#
#   build-ps5.sh KIT SOURCE TITLE_SOURCE [WORK]
#
#   KIT           the PS5 SDK kit (sdk/, vulkan/ with the RADV archive, as for the WWHD port)
#   SOURCE        TriAevum beta.1.1 source (b20ff67) with triaevum-ps5-runtime.patch applied
#   TITLE_SOURCE  the release's translated title source (source/titles/..., the folder with
#                 TITLE_SOURCE_MANIFEST.json and the 256 oot3d_whole_aot_shard_NNN.cpp)
#   WORK          where everything is built (default ./ps5-work)
#
# Result: WORK/dist/PPSA99307/ (eboot.bin, sce_sys, sce_module). Needs clang 18+ with
# lld, cmake >= 3.30 (the source uses CXX_COMPILER_FRONTEND_VARIANT), ninja, git, python3,
# and the compiler-rt builtins (libclang-rt-dev). The first run downloads and builds SDL2,
# shaderc/glslang/SPIRV-Tools, zlib, libzip, tinyxml2, spdlog, nlohmann_json (about 20 minutes);
# the 256 translated shards are the long step (about 1-2 hours on 2 cores).
# The output contains Nintendo-derived code: it is yours alone, do not share it.
set -euo pipefail
kit=$(cd "$1" && pwd) src=$(cd "$2" && pwd) title=$(cd "$3" && pwd)
work=${4:-$PWD/ps5-work}; mkdir -p "$work"; work=$(cd "$work" && pwd)
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
prefix=$work/deps-prefix; wd=$work/deps-work
mkdir -p "$prefix" "$wd"
# the kit's native tool (ELF -> the console's fake SELF)
if [[ ! -x $kit/vulkan/build/host/ps5-native-tool ]]; then
    mkdir -p "$kit/vulkan/build/host"; n=$kit/vulkan/tooling/native
    ${CXX:-c++} -std=c++20 -O2 "$n/native_app_builder.cpp" "$n/self_container.cpp" "$n/elf_object.cpp" \
        "$n/sce_module_writer.cpp" -lz -o "$kit/vulkan/build/host/ps5-native-tool"
fi
"$here/build-deps.sh" "$kit" "$prefix" "$wd"
"$here/build-sdl.sh" "$kit" "$prefix" "$wd"
[[ -d $wd/Vulkan-Headers ]] || git clone -q --depth 1 -b v1.4.321 https://github.com/KhronosGroup/Vulkan-Headers.git "$wd/Vulkan-Headers"
if [[ ! -f $prefix/lib/libshaderc.a ]]; then
    PS5_KIT=$kit PS5_DEPS_PREFIX=$prefix WORK=$wd/shaderc-build TOOLCHAIN=$here/toolchain.cmake "$here/build-shaderc.sh"
fi
# the Vulkan loader the console lacks: every vk* call forwards to RADV
if [[ ! -f $prefix/lib/libvulkan_shim.a ]]; then
    python3 "$here/vulkan-shim/gen_vk_shim.py" "$wd/Vulkan-Headers/include/vulkan/vulkan_core.h" "$wd/vk_shim.c"
    PS5_PAYLOAD_SDK=$kit/sdk "$kit/sdk/bin/prospero-clang" -O2 -c -I "$wd/Vulkan-Headers/include" "$wd/vk_shim.c" -o "$wd/vk_shim.o"
    "$kit/sdk/bin/llvm-ar" rcs "$prefix/lib/libvulkan_shim.a" "$wd/vk_shim.o"
fi
export PS5_KIT=$kit PS5_DEPS_PREFIX=$prefix WORK_DEPS=$wd TRIAEVUM_PS5_TITLE_DIR=$title
export PS5_DIST_DIR=$work/dist
"$here/configure-host.sh" "$src" "$work/build"
ninja -C "$work/build" oot3d_native_game
echo "done: $work/dist/PPSA99307"
