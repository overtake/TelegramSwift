#! /bin/sh

set -e
ARCH="$1"

SOURCE_DIR="$2"
BUILD_DIR=$(echo "$(cd "$(dirname "$3")"; pwd -P)/$(basename "$3")")

if [ "$ARCH" = "x86_64" ]; then
  IOS_PLATFORMDIR="$(xcode-select -p)/Platforms/MacOSX.platform"
  IOS_SYSROOT=($IOS_PLATFORMDIR/Developer/SDKs/MacOSX.sdk)
  export CFLAGS="-Wall -arch x86_64 -mmacosx-version-min=10.11 -funwind-tables"

  cd "$BUILD_DIR"
  mkdir build
  cd build

  touch toolchain.cmake
  echo "set(CMAKE_SYSTEM_NAME Darwin)" >> toolchain.cmake
  echo "set(CMAKE_SYSTEM_PROCESSOR AMD64)" >> toolchain.cmake
  echo "set(CMAKE_C_COMPILER $(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang)" >> toolchain.cmake

  cmake -G"Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake -DCMAKE_OSX_SYSROOT=${IOS_SYSROOT[0]} -DPNG_SUPPORTED=FALSE -DENABLE_SHARED=FALSE -DWITH_JPEG8=1 ../$SOURCE_DIR
  make
else
  echo "Unsupported architecture $ARCH"
  exit 1
fi
