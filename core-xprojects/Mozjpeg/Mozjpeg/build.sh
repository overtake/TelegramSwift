#! /bin/sh

set -e
set -x



SOURCE_DIR="$1"
BUILD_DIR=$(echo "$(cd "$(dirname "$3")"; pwd -P)/$(basename "$3")")
OUTPUTNAME="libjpeg.a"

MACOS_PLATFORMDIR="$PLATFORM_DIR"
MACOS_SYSROOT=($SDK_DIR)

cd "$BUILD_DIR"
mkdir build
cd build

for ARCH in $ARCHS
do

export CFLAGS="-Wall -arch $ARCH -mmacosx-version-min=10.11 -funwind-tables"

mkdir $ARCH
cd $ARCH

touch toolchain.cmake
echo "set(CMAKE_SYSTEM_NAME Darwin)" >> toolchain.cmake
if [ $ARCH = "arm64" ]; then
echo "set(CMAKE_SYSTEM_PROCESSOR aarch64)" >> toolchain.cmake
else
echo "set(CMAKE_SYSTEM_PROCESSOR AMD64)" >> toolchain.cmake
fi
echo "set(CMAKE_C_COMPILER $(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang)" >> toolchain.cmake

cmake -G"Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake -DCMAKE_OSX_SYSROOT=${MACOS_SYSROOT[0]} -DPNG_SUPPORTED=FALSE -DENABLE_SHARED=FALSE -DWITH_JPEG8=1 ../../$SOURCE_DIR
make

cd ..

done


#lipo -create -output universal_app x86_app arm_app
cd "$BUILD_DIR"
cd build

ARCH_COUNT=( $ARCHS )
ARCH_COUNT=${#ARCH_COUNT[@]}
if [[ $ARCH_COUNT -gt 1 ]] ; then
LIBRARIES=""
for ARCH in $ARCHS
do
LIBRARIES="$LIBRARIES ${BUILD_DIR}build/$ARCH/$OUTPUTNAME"
done
lipo -create -output $OUTPUTNAME $LIBRARIES
else
mv "${BUILD_DIR}build/$ARCHS/$OUTPUTNAME" "${BUILD_DIR}build/$OUTPUTNAME"
fi

mv "${BUILD_DIR}build/x86_64/jconfigint.h" "${BUILD_DIR}build/jconfigint.h"
mv "${BUILD_DIR}build/x86_64/jconfig.h" "${BUILD_DIR}build/jconfig.h"
