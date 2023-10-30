
set -e

set -e
set -x


SRC_DIR="$1"
BUILD_DIR=$(echo "$(cd "$(dirname "$3")"; pwd -P)/$(basename "$3")")



SRC_DIR="$1"
BUILD_DIR=$(echo "$(cd "$(dirname "$3")"; pwd -P)/$(basename "$3")")





rm -rf build || true
mkdir build

OUT_DIR="${BUILD_DIR}build"
mkdir -p $OUT_DIR



CROSS_TOP_MAC="$(xcode-select -p)/Platforms/MacOSX.platform"
CROSS_SDK_MAC="MacOSX.sdk"


SOURCE_DIR="$OUT_DIR/libwebp-master"
SOURCE_ARCHIVE="$SRC_DIR/libwebp-master.zip"

rm -rf "$SOURCE_DIR"

tar -xzf "$SOURCE_ARCHIVE" --directory "$OUT_DIR"
COMMON_ARGS="-DWEBP_LINK_STATIC=1 -DWEBP_BUILD_CWEBP=0 -DWEBP_BUILD_DWEBP=0 -DWEBP_BUILD_IMG2WEBP=0 -DWEBP_BUILD_ANIM_UTILS=0 -DWEBP_BUILD_GIF2WEBP=0 -DWEBP_BUILD_VWEBP=0 -DWEBP_BUILD_WEBPINFO=0 -DWEBP_BUILD_LIBWEBPMUX=0 -DWEBP_BUILD_WEBPMUX=0 -DWEBP_BUILD_EXTRAS=0"


MACOS_PLATFORMDIR="$PLATFORM_DIR"
MACOS_SYSROOT=($SDK_DIR)

cd $OUT_DIR
mkdir libwebp


for ARCH in $ARCHS
do

export CFLAGS="-Wall -arch $ARCH -mmacosx-version-min=10.11 -funwind-tables"

mkdir $ARCH
cd $ARCH

ROOTDIR=$OUT_DIR/$ARCH


touch toolchain.cmake
echo "set(CMAKE_SYSTEM_NAME Darwin)" >> toolchain.cmake
if [ $ARCH = "arm64" ]; then
echo "set(CMAKE_SYSTEM_PROCESSOR aarch64)" >> toolchain.cmake
else
echo "set(CMAKE_SYSTEM_PROCESSOR AMD64)" >> toolchain.cmake
fi

echo "set(CMAKE_C_COMPILER $(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang)" >> toolchain.cmake

cmake -G"Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake -DCMAKE_OSX_SYSROOT=${MACOS_SYSROOT[0]} $COMMON_ARGS ../libwebp-master
make

cd ..

LIBLIST+=" ${ROOTDIR}/libwebp.a"
DECLIBLIST+=" ${ROOTDIR}/libwebpdecoder.a"
SHARPLIBLIST+=" ${ROOTDIR}/libsharpyuv.a"
DEMUXLIBLIST+=" ${ROOTDIR}/libwebpdemux.a"

done

mkdir -p ${OUT_DIR}/libwebp/lib
mkdir -p ${OUT_DIR}/libwebp/include

echo "LIBLIST = ${LIBLIST}"
cp -a ${SOURCE_DIR}/src/webp/{decode,encode,types}.h ${OUT_DIR}/libwebp/include/
lipo -create ${LIBLIST} -output ${OUT_DIR}/libwebp/lib/libwebp.a


echo "DECLIBLIST = ${DECLIBLIST}"
cp -a ${SOURCE_DIR}/src/webp/{decode,types}.h ${OUT_DIR}/libwebp/include/
lipo -create ${DECLIBLIST} -output ${OUT_DIR}/libwebp/lib/libwebpdecoder.a


echo "SHARPLIBLIST = ${SHARPLIBLIST}"
cp -a ${SOURCE_DIR}/src/webp/{types,mux,mux_types}.h ${OUT_DIR}/libwebp/include/
lipo -create ${SHARPLIBLIST} -output ${OUT_DIR}/libwebp/lib/libsharpyuv.a

echo "DEMUXLIBLIST = ${DEMUXLIBLIST}"
cp -a ${SOURCE_DIR}/src/webp/{decode,types,mux_types,demux}.h ${OUT_DIR}/libwebp/include/
lipo -create ${DEMUXLIBLIST} -output ${OUT_DIR}/libwebp/lib/libwebpdemux.a

#
#  mv "${SOURCE_DIR}/src/.libs/libwebp.a" ${ROOTDIR}/libwebp.a
#  mv "${SOURCE_DIR}/src/.libs/libwebpdecoder.a" ${ROOTDIR}/libwebpdecoder.a
#  mv "${SOURCE_DIR}/src/mux/.libs/libwebpmux.a" ${ROOTDIR}/libwebpmux.a
#  mv "${SOURCE_DIR}/src/demux/.libs/libwebpdemux.a" ${ROOTDIR}/libwebpdemux.a
#
#  LIBLIST+=" ${ROOTDIR}/libwebp.a"
#  DECLIBLIST+=" ${ROOTDIR}/libwebpdecoder.a"
#  MUXLIBLIST+=" ${ROOTDIR}/libwebpmux.a"
#  DEMUXLIBLIST+=" ${ROOTDIR}/libwebpdemux.a"
#
#  make clean
#
#done
#
#mkdir -p ${OUT_DIR}/libwebp/lib
#mkdir -p ${OUT_DIR}/libwebp/include
#
#echo "LIBLIST = ${LIBLIST}"
#cp -a ${SOURCE_DIR}/src/webp/{decode,encode,types}.h ${OUT_DIR}/libwebp/include/
#lipo -create ${LIBLIST} -output ${OUT_DIR}/libwebp/lib/libwebp.a
#
#
#echo "DECLIBLIST = ${DECLIBLIST}"
#cp -a ${SOURCE_DIR}/src/webp/{decode,types}.h ${OUT_DIR}/libwebp/include/
#lipo -create ${DECLIBLIST} -output ${OUT_DIR}/libwebp/lib/libwebpdecoder.a
#
#
#echo "MUXLIBLIST = ${MUXLIBLIST}"
#cp -a ${SOURCE_DIR}/src/webp/{types,mux,mux_types}.h ${OUT_DIR}/libwebp/include/
#lipo -create ${MUXLIBLIST} -output ${OUT_DIR}/libwebp/lib/libwebpmux.a
#
#echo "DEMUXLIBLIST = ${DEMUXLIBLIST}"
#cp -a ${SOURCE_DIR}/src/webp/{decode,types,mux_types,demux}.h ${OUT_DIR}/libwebp/include/
#lipo -create ${DEMUXLIBLIST} -output ${OUT_DIR}/libwebp/lib/libwebpdemux.a
#
#


#
#
#set -e
#set -x
#
#

#
#
#
#CROSS_TOP_MAC="$(xcode-select -p)/Platforms/MacOSX.platform"
#CROSS_SDK_MAC="MacOSX.sdk"
#
#

#
#
#cd $SOURCE_DIR
#sh autogen.sh
#
#
#CROSS_TOP_MAC="$(xcode-select -p)/Platforms/MacOSX.platform"
#CROSS_SDK_MAC="MacOSX.sdk"
#
#
#DEVROOT=`xcode-select --print-path`/Toolchains/XcodeDefault.xctoolchain
#export PATH="${DEVROOT}/usr/bin:${PATH}"
#
#for ARCH in $ARCHS
#do
#  ARCH1=$ARCH
#  ARCH2=""
#  if [[ "${ARCH}" == "arm64" ]]; then
#    ARCH1="aarch64"
#    ARCH2="arm64"
#  fi
#
#
#  DIR="$(pwd)"
#  cd "$SOURCE_DIR"
#
#  ROOTDIR=$OUT_DIR/$ARCH
#  mkdir -p "${ROOTDIR}"
#
#  SDKROOT=$CROSS_TOP_MAC/Developer/SDKs/$CROSS_SDK_MAC
#  CFLAGS="-arch ${ARCH2:-${ARCH1}} -pipe -isysroot ${SDKROOT} -Os -DNDEBUG"
#  CFLAGS+=" -mmacosx-version-min=10.11 ${EXTRA_CFLAGS}"
#  ./configure --host=${ARCH1}-apple-darwin --prefix=${ROOTDIR} \
#    --build=$(./config.guess) \
#    --disable-shared --enable-static \
#    --enable-libwebpdecoder --enable-swap-16bit-csp \
#    --enable-libwebpmux \
#    CFLAGS="${CFLAGS}"
#
#  # run make only in the src/ directory to create libwebp.a/libwebpdecoder.a
#  cd src/
#  make V=0
#
#  mv "${SOURCE_DIR}/src/.libs/libwebp.a" ${ROOTDIR}/libwebp.a
#  mv "${SOURCE_DIR}/src/.libs/libwebpdecoder.a" ${ROOTDIR}/libwebpdecoder.a
#  mv "${SOURCE_DIR}/src/mux/.libs/libwebpmux.a" ${ROOTDIR}/libwebpmux.a
#  mv "${SOURCE_DIR}/src/demux/.libs/libwebpdemux.a" ${ROOTDIR}/libwebpdemux.a
#
#  LIBLIST+=" ${ROOTDIR}/libwebp.a"
#  DECLIBLIST+=" ${ROOTDIR}/libwebpdecoder.a"
#  MUXLIBLIST+=" ${ROOTDIR}/libwebpmux.a"
#  DEMUXLIBLIST+=" ${ROOTDIR}/libwebpdemux.a"
#
#  make clean
#
#done
#
#mkdir -p ${OUT_DIR}/libwebp/lib
#mkdir -p ${OUT_DIR}/libwebp/include
#
#echo "LIBLIST = ${LIBLIST}"
#cp -a ${SOURCE_DIR}/src/webp/{decode,encode,types}.h ${OUT_DIR}/libwebp/include/
#lipo -create ${LIBLIST} -output ${OUT_DIR}/libwebp/lib/libwebp.a
#
#
#echo "DECLIBLIST = ${DECLIBLIST}"
#cp -a ${SOURCE_DIR}/src/webp/{decode,types}.h ${OUT_DIR}/libwebp/include/
#lipo -create ${DECLIBLIST} -output ${OUT_DIR}/libwebp/lib/libwebpdecoder.a
#
#
#echo "MUXLIBLIST = ${MUXLIBLIST}"
#cp -a ${SOURCE_DIR}/src/webp/{types,mux,mux_types}.h ${OUT_DIR}/libwebp/include/
#lipo -create ${MUXLIBLIST} -output ${OUT_DIR}/libwebp/lib/libwebpmux.a
#
#echo "DEMUXLIBLIST = ${DEMUXLIBLIST}"
#cp -a ${SOURCE_DIR}/src/webp/{decode,types,mux_types,demux}.h ${OUT_DIR}/libwebp/include/
#lipo -create ${DEMUXLIBLIST} -output ${OUT_DIR}/libwebp/lib/libwebpdemux.a
#
#
