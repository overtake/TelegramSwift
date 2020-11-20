
set -e
set -x


SRC_DIR="$1"
BUILD_DIR=$(echo "$(cd "$(dirname "$3")"; pwd -P)/$(basename "$3")")



cd $BUILD_DIR

rm -rf build || true
mkdir build

OUT_DIR="${BUILD_DIR}build"
mkdir -p $OUT_DIR



CROSS_TOP_MAC="$(xcode-select -p)/Platforms/MacOSX.platform"
CROSS_SDK_MAC="MacOSX.sdk"


SOURCE_DIR="$OUT_DIR/opus-1.3.1"
SOURCE_ARCHIVE="$SRC_DIR/opus-1.3.1.tar.gz"

rm -rf "$SOURCE_DIR"

tar -xzf "$SOURCE_ARCHIVE" --directory "$OUT_DIR"



CROSS_TOP_MAC="$(xcode-select -p)/Platforms/MacOSX.platform"
CROSS_SDK_MAC="MacOSX.sdk"


DEVROOT=`xcode-select --print-path`/Toolchains/XcodeDefault.xctoolchain
export PATH="${DEVROOT}/usr/bin:${PATH}"

for ARCH in $ARCHS
do
  ARCH1=$ARCH
  ARCH2=""
  if [[ "${ARCH}" == "arm64" ]]; then
    ARCH1="aarch64"
    ARCH2="arm64"
  fi


  DIR="$(pwd)"
  cd "$SOURCE_DIR"

  ROOTDIR=$OUT_DIR/$ARCH
  mkdir -p "${ROOTDIR}"
    
  SDKROOT=$CROSS_TOP_MAC/Developer/SDKs/$CROSS_SDK_MAC
  CFLAGS="-arch ${ARCH2:-${ARCH1}} -pipe -isysroot ${SDKROOT} -Os -DNDEBUG"
  CFLAGS+=" -mmacosx-version-min=10.11 ${EXTRA_CFLAGS}"
  
  
  ./configure --host=${ARCH1}-apple-darwin \
            --enable-fixed-point \
            --disable-doc \
            --disable-extra-programs \
            --disable-asm \
            --build=$(./config.guess) \
            CFLAGS="${CFLAGS}" \
  
  

  # run make only in the src/ directory to create libwebp.a/libwebpdecoder.a
  make
  
  mv "${SOURCE_DIR}/.libs/libopus.a" ${ROOTDIR}/libopus.a
  
  LIBLIST+=" ${ROOTDIR}/libopus.a"
  
  make clean

done
#
mkdir -p ${OUT_DIR}/libopus/lib
mkdir -p ${OUT_DIR}/libopus/include/opus
#

cp -a ${SOURCE_DIR}/include/ ${OUT_DIR}/libopus/include/opus
lipo -create ${LIBLIST} -output ${OUT_DIR}/libopus/lib/libopus.a
