#!/usr/bin/env bash
# Cross-build the small libraries TriAevum needs, for the PS5, into PREFIX.
#   build-deps.sh KIT PREFIX [WORK]
set -euo pipefail
kit=$(cd "$1" && pwd); prefix=$2; work=${3:-$prefix/work}
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mkdir -p "$prefix" "$work"; prefix=$(cd "$prefix" && pwd); work=$(cd "$work" && pwd)
tc=(-G Ninja -DCMAKE_TOOLCHAIN_FILE="$here/toolchain.cmake" -DPS5_KIT="$kit" -DPS5_DEPS_PREFIX="$prefix"
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix" -DBUILD_SHARED_LIBS=OFF)
fetch() { [[ -d $work/$1 ]] || git clone -q --depth 1 -b "$3" "$2" "$work/$1"; }
build() { # name srcdir cmake-args...
    local name=$1 src=$2; shift 2
    [[ -f $prefix/.done-$name ]] && return
    cmake -S "$src" -B "$work/b-$name" "${tc[@]}" "$@" >"$work/$name.configure.log" 2>&1 || { tail -30 "$work/$name.configure.log"; exit 1; }
    cmake --build "$work/b-$name" >"$work/$name.build.log" 2>&1 || { tail -30 "$work/$name.build.log"; exit 1; }
    cmake --install "$work/b-$name" >>"$work/$name.build.log" 2>&1
    touch "$prefix/.done-$name"
}
fetch zlib https://github.com/madler/zlib.git v1.3.1
build zlib "$work/zlib" -DZLIB_BUILD_EXAMPLES=OFF
fetch tinyxml2 https://github.com/leethomason/tinyxml2.git 10.0.0
build tinyxml2 "$work/tinyxml2" -Dtinyxml2_BUILD_TESTING=OFF
fetch spdlog https://github.com/gabime/spdlog.git v1.15.0
build spdlog "$work/spdlog" -DSPDLOG_BUILD_EXAMPLE=OFF -DSPDLOG_BUILD_TESTS=OFF -DSPDLOG_BUILD_SHARED=OFF
fetch libzip https://github.com/nih-at/libzip.git v1.11.2
build libzip "$work/libzip" -DENABLE_BZIP2=OFF -DENABLE_LZMA=OFF -DENABLE_ZSTD=OFF -DENABLE_COMMONCRYPTO=OFF \
    -DENABLE_GNUTLS=OFF -DENABLE_MBEDTLS=OFF -DENABLE_OPENSSL=OFF -DENABLE_WINDOWS_CRYPTO=OFF \
    -DHAVE_CLONEFILE=0 -DHAVE_EXPLICIT_BZERO=0 -DHAVE_EXPLICIT_MEMSET=0 -DHAVE_FTS_H=0 -DHAVE_FTS_OPEN=0 \
    -DHAVE_GETPROGNAME=0 -DHAVE_MEMCPY_S=0 -DHAVE_SETMODE=0 -DHAVE_STRERRORLEN_S=0 -DHAVE_STRERROR_S=0 \
    -DHAVE_STRICMP=0 -DHAVE_STRNCPY_S=0 -DHAVE__CLOSE=0 -DHAVE__DUP=0 -DHAVE__FDOPEN=0 -DHAVE__FILENO=0 \
    -DHAVE__SETMODE=0 -DHAVE__STRDUP=0 -DHAVE__UNLINK=0 \
    -DBUILD_TOOLS=OFF -DBUILD_REGRESS=OFF -DBUILD_OSSFUZZ=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF
fetch nlohmann-json https://github.com/nlohmann/json.git v3.11.3
build nlohmann-json "$work/nlohmann-json" -DJSON_BuildTests=OFF
echo "deps ready in $prefix"
