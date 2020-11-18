#! /bin/sh

set -e


SOURCE_DIR="$2"
BUILD_DIR=$(echo "$(cd "$(dirname "$3")"; pwd -P)/$(basename "$3")")
OUTPUTNAME="libjpeg.a"

MACOS_PLATFORMDIR="$(xcode-select -p)/Platforms/MacOSX.platform"
MACOS_SYSROOT=($MACOS_PLATFORMDIR/Developer/SDKs/MacOSX.sdk)

for ARCH in $ARCHS
do

export CFLAGS="-Wall -arch $ARCH -mmacosx-version-min=10.11 -funwind-tables"

cd "$BUILD_DIR"
mkdir build
cd build

mkdir $ARCH
cd $ARCH

touch toolchain.cmake
echo "set(CMAKE_SYSTEM_NAME Darwin)" >> toolchain.cmake
echo "set(CMAKE_SYSTEM_PROCESSOR AMD64)" >> toolchain.cmake
echo "set(CMAKE_C_COMPILER $(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang)" >> toolchain.cmake

cmake -G"Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake -DCMAKE_OSX_SYSROOT=${MACOS_SYSROOT[0]} -DPNG_SUPPORTED=FALSE -DENABLE_SHARED=FALSE -DWITH_JPEG8=1 ../../$SOURCE_DIR
make

done


#lipo -create -output universal_app x86_app arm_app
cd "$BUILD_DIR"
if [[ $ARCHS -gt 1 ]] ; then

LIBRARIES=""
for ARCH in $ARCHS
do
LIBRARIES="{$LIBRARIES} $BUILD_DIR/$ARCH/$OUTPUTNAME"
done
lipo -create -output $OUTPUTNAME LIBRARIES
else
mv "$BUILD_DIR/$ARCHS[0]/$OUTPUTNAME" "$BUILD_DIR/$OUTPUTNAME"
fi
