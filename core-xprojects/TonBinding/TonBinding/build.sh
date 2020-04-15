#/bin/sh

set -x
set -e

OUT_DIR="$1"
SOURCE_DIR="$2"
openssl_base_path="$3"
if [ -z "$openssl_base_path" ]; then
echo "Usage: sh build.sh path/to/openssl"
exit 1
fi

if [ ! -d "$openssl_base_path" ]; then
echo "$openssl_base_path not found"
exit 1
fi

if [ -d "$OUT_DIR/build/out" ]
then
exit 0
fi

td_path="$SOURCE_DIR"

mkdir -p "$OUT_DIR"
mkdir -p "$OUT_DIR/build"
cd "$OUT_DIR/build"

platforms="macOS"
for platform in $platforms; do
install="install-${platform}"
build="build-${platform}"
openssl_path="$openssl_base_path"
echo "OpenSSL path = ${openssl_path}"
openssl_crypto_library="${openssl_path}/lib/libcrypto.a"
options="$options -DOPENSSL_FOUND=1"
options="$options -DOPENSSL_CRYPTO_LIBRARY=${openssl_crypto_library}"
options="$options -DOPENSSL_INCLUDE_DIR=${openssl_path}/include"
options="$options -DOPENSSL_LIBRARIES=${openssl_crypto_library}"
options="$options -DTON_ONLY_TONLIB=ON"
options="$options -DCMAKE_BUILD_TYPE=Release"
options="$options -DCMAKE_OSX_DEPLOYMENT_TARGET=10.11"
options="$options -DTON_ARCH="
rm -rf $build
mkdir -p $build
mkdir -p $install
cd $build
cmake $td_path $options -DCMAKE_INSTALL_PREFIX=../${install} ${SOURCE_DIR} -GNinja
ninja install || exit
cd ..
done
mkdir -p $platform

mkdir -p "out"
cp -r "install-macOS/include" "out/"
mkdir -p "out/lib"

for f in install-macOS/lib/*.a; do
lib_name=$(basename "$f")
lipo -create "install-macOS/lib/$lib_name" -o "out/lib/$lib_name"
done

