#/bin/sh

set -x
set -e

SOURCE_DIR="$1"
DEPOT_DIR="$2"
OPENSSL_DIR="$3"

BUILD_DIR="${PROJECT_DIR}/build/"

rm -rf $BUILD_DIR || true
mkdir -p $BUILD_DIR || true

export PATH="$PATH:$DEPOT_DIR"


cp -R $SOURCE_DIR $BUILD_DIR



rm -rf "${BUILD_DIR}src/openssl"
cp -R $OPENSSL_DIR/lib "${BUILD_DIR}src/openssl"
cp -R $OPENSSL_DIR/include "${BUILD_DIR}src/openssl/include"
pushd "${BUILD_DIR}src"



#

#if [ "$ARCH" == "x64" ]; then
#  OUT_DIR="ios_sim"
#fi
#

LIBS=""
for ARCH in $ARCHS
do


CURRENT_ARCH=$ARCH
if [ "$ARCH" == "x86_64" ]; then
  CURRENT_ARCH="x64"
fi

if [ "$ARCH" == "arm64" ]; then
  CURRENT_ARCH="arm64"
fi


OUT_DIR=$CURRENT_ARCH
buildtools/mac/gn gen out/$OUT_DIR --args="use_xcode_clang=false target_cpu=\"$CURRENT_ARCH\""' target_os="mac" is_debug=false is_component_build=false rtc_include_tests=false use_rtti=true rtc_use_x11=false use_custom_libcxx=false use_custom_libcxx_for_host=false rtc_build_ssl=false rtc_build_examples=false rtc_build_tools=false mac_deployment_target="10.11" is_unsafe_developer_build=false rtc_enable_protobuf=false rtc_include_builtin_video_codecs=true rtc_build_libvpx=true rtc_libvpx_build_vp9=true rtc_use_gtk=false rtc_use_metal_rendering=true mac_sdk_min="11.0" rtc_desktop_capture_supported=false strip_debug_info=true symbol_level=0 ios_enable_code_signing=false'
ninja -C out/$OUT_DIR mac_framework_objc_static

LIBS="$LIBS ${BUILD_DIR}src/out/$OUT_DIR/obj/sdk/libmac_framework_objc_static.a"

done

LIB_PATH=${BUILD_DIR}webrtc
mkdir -p $LIB_PATH
lipo -create $LIBS -output "$LIB_PATH/libmac_framework_objc_static.a" || exit 1
rm -rf ${BUILD_DIR}src/out
#
#popd


#--developer_dir
