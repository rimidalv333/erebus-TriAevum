#!/usr/bin/env bash
# Cross-build SDL2 (with the console's drivers) and the platform layer, for the PS5, into PREFIX.
#   build-sdl.sh KIT PREFIX [WORK]
set -euo pipefail
kit=$(cd "$1" && pwd); prefix=$2; work=${3:-$prefix/work}
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mkdir -p "$prefix" "$work"; prefix=$(cd "$prefix" && pwd); work=$(cd "$work" && pwd)
tag=release-2.32.10
sdl=$work/SDL2
if [[ ! -f $sdl/.ps5-sdl ]]; then
    rm -rf "$sdl"
    git clone -q --depth 1 -b "$tag" https://github.com/libsdl-org/SDL.git "$sdl" 2>/dev/null
    git -C "$sdl" apply --whitespace=nowarn "$here/sdl2-core.patch"
    touch "$sdl/.ps5-sdl"
fi
tc=(-G Ninja -DCMAKE_TOOLCHAIN_FILE="$here/toolchain.cmake" -DPS5_KIT="$kit" -DPS5_DEPS_PREFIX="$prefix"
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix")
if [[ ! -f $prefix/.done-sdl2 ]]; then
    opts=()
    for off in SHARED TEST X11 WAYLAND KMSDRM RPI VIVANTE DIRECTFB OPENGL OPENGLES RENDER_OGL RENDER_OGL_ES2 \
               OSS ALSA JACK PIPEWIRE PULSEAUDIO ESD ARTS NAS SNDIO FUSIONSOUND DISKAUDIO DUMMYAUDIO DUMMYVIDEO \
               LIBUDEV DBUS IBUS HIDAPI LIBUSB HAPTIC SENSOR POWER LOADSO CAMERA OFFSCREEN VIRTUAL_JOYSTICK \
               METAL RENDER_METAL ASAN LIBSAMPLERATE ; do
        opts+=("-DSDL_$off=OFF")
    done
    cmake -S "$sdl" -B "$work/b-sdl2" "${tc[@]}" "${opts[@]}" -DSDL_STATIC=ON -DSDL2_DISABLE_SDL2MAIN=ON \
        -DSDL_VULKAN=ON -DSDL_CLOCK_GETTIME=ON \
        -DSDL_PS5_PORT_DIR="$here/sdl2" -DSDL_PS5_PLATFORM_DIR="$here/platform" \
        -DSDL_TESTS=OFF -DSDL_INSTALL_TESTS=OFF >"$work/sdl2.configure.log" 2>&1 || { tail -40 "$work/sdl2.configure.log"; exit 1; }
    cmake --build "$work/b-sdl2" >"$work/sdl2.build.log" 2>&1 || { grep -E "error|Error" -B2 -A6 "$work/sdl2.build.log" | head -60; exit 1; }
    cmake --install "$work/b-sdl2" >>"$work/sdl2.build.log" 2>&1
    touch "$prefix/.done-sdl2"
fi
# The platform layer: klog, the pad, the title's exit, and the libc names a title cannot import
if [[ ! -f $prefix/lib/libps5_platform.a ]]; then
    mkdir -p "$work/platform"
    title=${PS5_TITLE_NAME:-TriAevum}
    for f in platform shims startup; do
        PS5_PAYLOAD_SDK="$kit/sdk" "$kit/sdk/bin/prospero-clang" -std=gnu2x -O2 -g1 -march=znver2 -fno-omit-frame-pointer \
            -DPS5_TITLE_NAME="\"$title\"" -I"$here/platform" -I"$prefix/include/SDL2" -c "$here/platform/$f.c" -o "$work/platform/$f.o"
    done
    "$kit/sdk/bin/llvm-ar" rcs "$prefix/lib/libps5_platform.a" "$work/platform"/*.o
fi
echo "SDL2 and the platform layer are ready in $prefix"
