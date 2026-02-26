#!/bin/sh

set -e

SOURCE_DIR="$1"
BUILD_DIR="$2"

if [ -z "$SOURCE_DIR" ] || [ -z "$BUILD_DIR" ]; then
    echo "Usage: $0 SOURCE_DIR BUILD_DIR"
    echo "Example: $0 /path/to/dav1d/source /path/to/build/directory"
    exit 1
fi

MESON_OPTIONS="--buildtype=release --default-library=static -Denable_tools=false -Denable_tests=false"

# Ensure build directory exists
mkdir -p "$BUILD_DIR"

# Build for ARM64
echo "Building for arm64..."
mkdir -p "$BUILD_DIR/arm64"
pushd "$BUILD_DIR/arm64"

meson setup "$SOURCE_DIR" --cross-file="$PWD/../../dav1d-arm64.meson" $MESON_OPTIONS
ninja
popd

# Build for x86_64
echo "Building for x86_64..."
mkdir -p "$BUILD_DIR/x86_64"
pushd "$BUILD_DIR/x86_64"

meson setup "$SOURCE_DIR" --cross-file="$PWD/../../dav1d-x86_64.meson" $MESON_OPTIONS
ninja
popd

# Create universal binary
echo "Creating universal binary..."
mkdir -p "$BUILD_DIR/dav1d/lib"
lipo -create \
    "$BUILD_DIR/arm64/src/libdav1d.a" \
    "$BUILD_DIR/x86_64/src/libdav1d.a" \
    -output "$BUILD_DIR/dav1d/lib/libdav1d.a"

# Copy include files from the source directory
echo "Copying include files from source directory..."
mkdir -p "$BUILD_DIR/dav1d/include"
cp -R "$SOURCE_DIR/include/dav1d" "$BUILD_DIR/dav1d/include/"

echo "Universal library created at $BUILD_DIR/dav1d/lib/libdav1d.a"
echo "Headers copied to $BUILD_DIR/dav1d/include/"
