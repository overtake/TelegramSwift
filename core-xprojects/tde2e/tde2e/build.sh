#!/bin/sh

set -e

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
options="$options -DOPENSSL_CRYPTO_LIBRARY=${openssl_crypto_library}"
options="$options -DOPENSSL_INCLUDE_DIR=${OPENSSL_DIR}/include"
options="$options -DCMAKE_BUILD_TYPE=Release"

mkdir -p "$BUILD_DIR"

# Build for arm64
echo "Building for arm64..."
ARM64_DIR="$BUILD_DIR/arm64"
mkdir -p "$ARM64_DIR"
pushd "$ARM64_DIR"

cmake "$SOURCE_DIR" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_BUILD_TYPE=Release \
    $options

cmake --build . --target tde2e -j$(sysctl -n hw.ncpu)
popd

# Build for x86_64
echo "Building for x86_64..."
X86_64_DIR="$BUILD_DIR/x86_64"
mkdir -p "$X86_64_DIR"
pushd "$X86_64_DIR"

cmake "$SOURCE_DIR" \
    -DCMAKE_OSX_ARCHITECTURES=x86_64 \
    -DCMAKE_BUILD_TYPE=Release \
    $options

cmake --build . --target tde2e -j$(sysctl -n hw.ncpu)
popd

# Create universal binary
echo "Creating universal binary..."
UNIVERSAL_DIR="$BUILD_DIR/tde2e"
mkdir -p "$UNIVERSAL_DIR/lib"

lipo -create \
    "$ARM64_DIR/tde2e/libtde2e.a" \
    "$X86_64_DIR/tde2e/libtde2e.a" \
    -output "$UNIVERSAL_DIR/lib/libtde2e.a"

echo "Universal binary created at $UNIVERSAL_DIR/lib/tde2e"

echo "Copying include files from source directory..."
INCLUDE_DIR="$UNIVERSAL_DIR/include/td/e2e"
mkdir -p "$INCLUDE_DIR"
cp "$SOURCE_DIR/tde2e/td/e2e/e2e_api.h" "$INCLUDE_DIR/"
cp "$SOURCE_DIR/tde2e/td/e2e/e2e_errors.h" "$INCLUDE_DIR/"

echo "Headers copied to $INCLUDE_DIR"
