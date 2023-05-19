#!/bin/bash

set -x
set -e

SRC_DIR="$1"
BUILD_DIR=$(echo "$(cd "$(dirname "$3")"; pwd -P)/$(basename "$3")")



cd $BUILD_DIR

rm -rf build || true
mkdir build

OUT_DIR="${BUILD_DIR}build"




CROSS_TOP_MAC="$(xcode-select -p)/Platforms/MacOSX.platform"
CROSS_SDK_MAC="MacOSX.sdk"


SOURCE_DIR="$OUT_DIR/openssl-1.1.1d"
SOURCE_ARCHIVE="$SRC_DIR/openssl-1.1.1d.tar.gz"

rm -rf "$SOURCE_DIR"

tar -xzf "$SOURCE_ARCHIVE" --directory "$OUT_DIR"

export CROSS_COMPILE=`xcode-select --print-path`/Toolchains/XcodeDefault.xctoolchain/usr/bin/

function build_for ()
{
  DIR="$(pwd)"
  cd "$SOURCE_DIR"

  PLATFORM="$1"
  ARCH="$2"
  CROSS_TOP_ENV="CROSS_TOP_$3"
  CROSS_SDK_ENV="CROSS_SDK_$3"

  make clean || true

  export CROSS_TOP="${!CROSS_TOP_ENV}"
  export CROSS_SDK="${!CROSS_SDK_ENV}"

  MINIMAL_FLAGS=(\
    "no-shared" \
    "no-afalgeng" \
    "no-aria" \
    "no-asan" \
    "no-async" \
    "no-autoalginit" \
    "no-autoerrinit" \
    "no-autoload-config" \
    "no-bf" \
    "no-blake2" \
    "no-buildtest-c++" \
    "no-camellia" \
    "no-capieng" \
    "no-cast" \
    "no-chacha" \
    "no-cmac" \
    "no-cms" \
    "no-comp" \
    "no-crypto-mdebug" \
    "no-crypto-mdebug-backtrace" \
    "no-ct" \
    "no-deprecated" \
    "no-des" \
    "no-devcryptoeng" \
    "no-dgram" \
    "no-dh" \
    "no-dsa" \
    "no-dtls" \
    "no-dynamic-engine" \
    "no-ec" \
    "no-ec2m" \
    "no-ecdh" \
    "no-ecdsa" \
    "no-ec_nistp_64_gcc_128" \
    "no-egd" \
    "no-engine" \
    "no-err" \
    "no-external-tests" \
    "no-filenames" \
    "no-fuzz-libfuzzer" \
    "no-fuzz-afl" \
    "no-gost" \
    "no-heartbeats" \
    "no-idea" \
    "no-makedepend" \
    "no-md2" \
    "no-md4" \
    "no-mdc2" \
    "no-msan" \
    "no-multiblock" \
    "no-nextprotoneg" \
    "no-pinshared" \
    "no-ocb" \
    "no-ocsp" \
    "no-pic" \
    "no-poly1305" \
    "no-posix-io" \
    "no-psk" \
    "no-rc2" \
    "no-rc4" \
    "no-rc5" \
    "no-rfc3779" \
    "no-rmd160" \
    "no-scrypt" \
    "no-sctp" \
    "no-shared" \
    "no-siphash" \
    "no-sm2" \
    "no-sm3" \
    "no-sm4" \
    "no-sock" \
    "no-srp" \
    "no-srtp" \
    "no-sse2" \
    "no-ssl" \
    "no-ssl-trace" \
    "no-static-engine" \
    "no-stdio" \
    "no-tests" \
    "no-tls" \
    "no-ts" \
    "no-ubsan" \
    "no-ui-console" \
    "no-unit-test" \
    "no-whirlpool" \
    "no-weak-ssl-ciphers" \
    "no-zlib" \
    "no-zlib-dynamic" \
  )

  DEFAULT_FLAGS=(\
    "no-shared" \
    "no-asm" \
    "no-ssl3" \
    "no-comp" \
    "no-hw" \
    "no-engine" \
    "no-async" \
    "no-tests" \
  )

  ./Configure $PLATFORM "-arch $ARCH" ${DEFAULT_FLAGS[@]} --prefix="${ABS_TMP_DIR}/${ARCH}" || exit 1
  
  make || exit 2
  unset CROSS_TOP
  unset CROSS_SDK

  cd "$DIR"
}

patch "$SOURCE_DIR/Configurations/10-main.conf" < "$PWD/OpenSSLEncryption/patch-conf.diff" || exit 1


for ARCH in $ARCHS
do
  build_for darwin64-$ARCH-cc $ARCH MAC
  mkdir build/$ARCH
  mv "build/openssl-1.1.1d/libssl.a" "build/$ARCH/libssl.a"
  mv "build/openssl-1.1.1d/libcrypto.a" "build/$ARCH/libcrypto.a"
done


ARCH_COUNT=( $ARCHS )
ARCH_COUNT=${#ARCH_COUNT[@]}
if [[ $ARCH_COUNT -gt 1 ]] ; then
LIBSSLA=""
LIBCRYPTO=""
mkdir -p ${BUILD_DIR}build/openssl/lib
mv $SOURCE_DIR/include ${BUILD_DIR}build/openssl/include
for ARCH in $ARCHS
do
LIBSSLA="$LIBSSLA ${BUILD_DIR}build/$ARCH/libssl.a"
LIBCRYPTO="$LIBCRYPTO ${BUILD_DIR}build/$ARCH/libcrypto.a"
done
lipo -create -output ${BUILD_DIR}build/openssl/lib/libssl.a $LIBSSLA
lipo -create -output ${BUILD_DIR}build/openssl/lib/libcrypto.a $LIBCRYPTO
else
mv "${BUILD_DIR}build/$ARCHS/libssl.a" "${BUILD_DIR}build/libssl.a"
mv "${BUILD_DIR}build/$ARCHS/libcrypto.a" "${BUILD_DIR}build/libcrypto.a"
fi


#cp -r "${TMP_DIR}/$ARCH/include" "${TMP_DIR}/"
#if [ "$ARCH" == "arm64" ]; then
#  patch -p3 "${TMP_DIR}/include/openssl/opensslconf.h" < "$SRC_DIR/patch-include.patch" || exit 1
#fi
#
#DFT_DIST_DIR="$OUT_DIR/out"
#rm -rf "$DFT_DIST_DIR"
#mkdir -p "$DFT_DIST_DIR"
#
#DIST_DIR="${DIST_DIR:-$DFT_DIST_DIR}"
#mkdir -p "${DIST_DIR}"
#cp -r "${TMP_DIR}/include" "${TMP_DIR}/$ARCH/lib" "${DIST_DIR}"
