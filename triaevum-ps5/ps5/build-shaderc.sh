#!/bin/sh
# Cross-build shaderc (+glslang, SPIRV-Tools) for the PS5 as one static libshaderc.a.
# Pins match runtime/three_ds_recomp/cmake/dependencies/android-vulkan.cmake.
set -e
: "${PS5_KIT:?}" "${PS5_DEPS_PREFIX:?}" "${WORK:?}" "${TOOLCHAIN:?}"
mkdir -p "$WORK"; cd "$WORK"
fetch() { # dir url commit
  [ -d "$1/.git" ] || git clone -q "$2" "$1"
  git -C "$1" checkout -q "$3"
}
fetch spirv-headers https://github.com/KhronosGroup/SPIRV-Headers.git ad9184e76a66b1001c29db9b0a3e87f646c64de0
fetch spirv-tools https://github.com/KhronosGroup/SPIRV-Tools.git c1cb30bb04e2bf911755a40df1242cc6e3d83e26
fetch glslang https://github.com/KhronosGroup/glslang.git 5ed4003a18a10a9d1bd7e43aaf1664499abffa83
fetch shaderc https://github.com/google/shaderc.git d5f08ae5c5a9a45165578445cbd0f9adf0223448
cmake -S shaderc -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" -DPS5_KIT="$PS5_KIT" \
  -DPS5_DEPS_PREFIX="$PS5_DEPS_PREFIX" -DCMAKE_BUILD_TYPE=Release \
  -DSHADERC_SKIP_TESTS=ON -DSHADERC_SKIP_EXAMPLES=ON -DSHADERC_SKIP_COPYRIGHT_CHECK=ON \
  -DSHADERC_SKIP_EXECUTABLES=ON -DSPIRV_SKIP_EXECUTABLES=ON -DSPIRV_SKIP_TESTS=ON \
  -DENABLE_GLSLANG_BINARIES=OFF -DSHADERC_ENABLE_SHARED_CRT=OFF -DBUILD_SHARED_LIBS=OFF \
  -DSHADERC_SPIRV_HEADERS_DIR="$PWD/spirv-headers" -DSHADERC_SPIRV_TOOLS_DIR="$PWD/spirv-tools" \
  -DSHADERC_GLSLANG_DIR="$PWD/glslang" -DCMAKE_POSITION_INDEPENDENT_CODE=OFF \
  -DENABLE_OPT=ON -DSPIRV_WERROR=OFF
cmake --build build --target shaderc_combined -j"$(nproc)"
mkdir -p "$PS5_DEPS_PREFIX/include" "$PS5_DEPS_PREFIX/lib"
cp -r shaderc/libshaderc/include/shaderc "$PS5_DEPS_PREFIX/include/"
cp build/libshaderc/libshaderc_combined.a "$PS5_DEPS_PREFIX/lib/libshaderc.a"
