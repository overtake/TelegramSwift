#/bin/sh

set -x
set -e

SOURCE_DIR="$1"

OPENSSL_DIR="$2"
JPEG_DIR="$3"
OPUS_DIR="$4"
FFMPEG_DIR="$5"


BUILD_DIR="${PROJECT_DIR}/build/"

rm -rf $BUILD_DIR || true
mkdir -p $BUILD_DIR || true


cp -R $SOURCE_DIR $BUILD_DIR



LIBS=""
for ARCH in $ARCHS
do

pushd $BUILD_DIR

CURRENT_ARCH=$ARCH


OUT_DIR=$CURRENT_ARCH
mkdir -p $OUT_DIR || true
cd $OUT_DIR

cmake -G Ninja \
    -DCMAKE_OSX_ARCHITECTURES=$CURRENT_ARCH \
    -DTG_OWT_SPECIAL_TARGET=mac \
    -DCMAKE_BUILD_TYPE=Release \
    -DNDEBUG=1 \
    -DTG_OWT_LIBJPEG_INCLUDE_PATH=$JPEG_DIR \
    -DTG_OWT_OPENSSL_INCLUDE_PATH=$OPENSSL_DIR \
    -DTG_OWT_OPUS_INCLUDE_PATH=$OPUS_DIR \
    -DTG_OWT_FFMPEG_INCLUDE_PATH=$FFMPEG_DIR ..

ninja
LIBS="$LIBS ${BUILD_DIR}$OUT_DIR/libtg_owt.a"
    # -DCMAKE_BUILD_TYPE=Debug

cd ..

done
#
LIB_PATH=${BUILD_DIR}webrtc
rm -rf $LIB_PATH || true
mkdir -p $LIB_PATH
lipo -create $LIBS -output "$LIB_PATH/libmac_framework_objc_static.a" || exit 1


#popd


#--developer_dir
