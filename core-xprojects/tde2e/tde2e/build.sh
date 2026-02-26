#!/bin/sh

set -e
set -x

SOURCE_DIR="$1"
BUILD_DIR="$2"
OPENSSL_DIR="$3"

if [ -z "$SOURCE_DIR" ] || [ -z "$BUILD_DIR" ] || [ -z "$OPENSSL_DIR" ]; then
    echo "Usage: $0 SOURCE_DIR BUILD_DIR OPENSSL_DIR"
    echo "Example: $0 /path/to/td /path/to/build /path/to/openssl"
    exit 1
fi

openssl_crypto_library="${OPENSSL_DIR}/lib/libcrypto.a"
options=""
options="$options -DOPENSSL_FOUND=1"
#options="$options -DOPENSSL_CRYPTO_LIBRARY=${openssl_crypto_library}"
options="$options -DOPENSSL_INCLUDE_DIR=${OPENSSL_DIR}/include"
options="$options -DCMAKE_BUILD_TYPE=Release"

# Step 1: Generate TDLib source files once
GEN_DIR="$BUILD_DIR/native-gen"
mkdir -p "$GEN_DIR"
pushd "$GEN_DIR"
cmake -DTD_GENERATE_SOURCE_FILES=ON "$SOURCE_DIR"
cmake --build . -- -j$(sysctl -n hw.ncpu)
popd

# Step 2: Build for arm64
echo "Building for arm64..."
ARM64_DIR="$BUILD_DIR/arm64"
mkdir -p "$ARM64_DIR"
pushd "$ARM64_DIR"

cmake "$SOURCE_DIR" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    $options

cmake --build . --target tde2e -j$(sysctl -n hw.ncpu)
popd

# Step 3: Build for x86_64
echo "Building for x86_64..."
X86_64_DIR="$BUILD_DIR/x86_64"
mkdir -p "$X86_64_DIR"
pushd "$X86_64_DIR"

cmake "$SOURCE_DIR" \
    -DCMAKE_OSX_ARCHITECTURES=x86_64 \
    $options

cmake --build . --target tde2e -j$(sysctl -n hw.ncpu)
popd

# Step 4: Create universal binary
echo "Creating universal binary..."
UNIVERSAL_DIR="$BUILD_DIR/tde2e"
mkdir -p "$UNIVERSAL_DIR/lib"

lipo -create \
    "$ARM64_DIR/tde2e/libtde2e.a" \
    "$X86_64_DIR/tde2e/libtde2e.a" \
    -output "$UNIVERSAL_DIR/lib/libtde2e.a"

echo "Universal binary created at $UNIVERSAL_DIR/lib/libtde2e.a"


lipo -create \
    "$ARM64_DIR/tdutils/libtdutils.a" \
    "$X86_64_DIR/tdutils/libtdutils.a" \
    -output "$UNIVERSAL_DIR/lib/libtdutils.a"

echo "Universal binary created at $UNIVERSAL_DIR/lib/libtdutils.a"
