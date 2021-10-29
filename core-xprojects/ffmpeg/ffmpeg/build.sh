#!/bin/sh

set -e
set -x


SOURCE_DIR=$1

BUILD_DIR=$(echo "$(cd "$(dirname "$3")"; pwd -P)/$(basename "$3")")
BUILD_DIR="${BUILD_DIR}build/"

FAT="${BUILD_DIR}ffmpeg"

SCRATCH="${BUILD_DIR}scratch"
THIN="${BUILD_DIR}thin"

PKG_CONFIG="$SOURCE_DIR/pkg-config"






rm -rf $BUILD_DIR || true
mkdir -p $BUILD_DIR || true


LIBOPUS_PATH="${BUILD_DIR}../../libopus/build/libopus"

FF_VERSION="4.1"
SOURCE="$SOURCE_DIR/ffmpeg-$FF_VERSION"

GAS_PREPROCESSOR_PATH="$SOURCE_DIR/gas-preprocessor.pl"




export PATH="$SOURCE_DIR:$PATH"

LIB_NAMES="libavcodec libavformat libavutil libswresample"


CONFIGURE_FLAGS="--enable-cross-compile --disable-programs \
				 --disable-armv5te --disable-armv6 --disable-armv6t2 \
                 --disable-doc --enable-pic --disable-all --disable-everything \
                 --enable-avcodec  \
                 --enable-swresample \
                 --enable-avformat \
                 --disable-xlib \
                 --enable-libopus \
                 --enable-audiotoolbox \
                 --enable-bsf=aac_adtstoasc \
                 --enable-decoder=h264,hevc,libopus,mp3,aac,flac,alac,pcm_s16le,pcm_s24le,gsm_ms \
                 --enable-demuxer=aac,mov,m4v,mp3,ogg,libopus,flac,wav,aiff,matroska \
                 --enable-parser=aac,h264,mp3,libopus \
                 --enable-protocol=file \
                 --enable-muxer=mp4 \
                 "


CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-debug"

COMPILE="y"

DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET


if [ "$COMPILE" ]
then
	if [ ! `which yasm` ]; then
		echo 'Yasm not found'
		exit 1
	fi
	if [ ! `which pkg-config` ]; then
		echo 'pkg-config not found'
		exit 1
	else
		echo "PATH=$PATH"
		echo "pkg-config=$(which pkg-config)"
	fi
	if [ ! `which "$GAS_PREPROCESSOR_PATH"` ]; then
		echo '$GAS_PREPROCESSOR_PATH not found.'
		exit 1
	fi

	if [ ! -r $SOURCE ]; then
		echo "FFmpeg source not found at $SOURCE"
		exit 1
	fi

	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		pushd "$SCRATCH/$ARCH"

		

		CFLAGS="-arch $ARCH"
		if [ "$ARCH" = "x86_64" ]
		then
		    PLATFORM="MacOSX"
		    CFLAGS="$CFLAGS -mmacosx-version-min=$DEPLOYMENT_TARGET"
		else
		    PLATFORM="MacOSX"
		    CFLAGS="$CFLAGS -mmacosx-version-min=$DEPLOYMENT_TARGET"
		    if [ "$ARCH" = "arm64" ]
		    then
		        EXPORT="GASPP_FIX_XCODE5=1"
		    fi
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang"

		if [ "$ARCH" = "arm64" ]
		then
		    AS="$GAS_PREPROCESSOR_PATH -arch aarch64 -- $CC"
		else
		    AS="$GAS_PREPROCESSOR_PATH -- $CC"
		fi

		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		CONFIGURED_MARKER="$THIN/$ARCH/configured_marker"
		CONFIGURED_MARKER_CONTENTS=""
		if [ -r "$CONFIGURED_MARKER" ]
		then
			CONFIGURED_MARKER_CONTENTS=`cat "$CONFIGURED_MARKER"`
		fi
		if [ "$CONFIGURED_MARKER_CONTENTS" = "$CONFIGURE_FLAGS" ]
		then
			echo "1" >/dev/null
		else
			mkdir -p "$THIN/$ARCH"
			TMPDIR=${TMPDIR/%\/} "$SOURCE/configure" \
			    --target-os=darwin \
			    --arch=$ARCH \
			    --cc="$CC" \
			    --as="$AS" \
			    $CONFIGURE_FLAGS \
			    --extra-cflags="$CFLAGS" \
			    --extra-ldflags="$LDFLAGS" \
			    --prefix="$THIN/$ARCH" \
			    --pkg-config="$PKG_CONFIG" \
			    --pkg-config-flags="--libopus_path $LIBOPUS_PATH" \
			|| exit 1
			echo "$CONFIGURE_FLAGS" > "$CONFIGURED_MARKER"
		fi

		CORE_COUNT=`sysctl -n hw.logicalcpu`
		make -j$CORE_COUNT install $EXPORT || exit 1

		popd
	done
fi


mkdir -p "$FAT"/lib
set - $ARCHS
for LIB in "$THIN/$1/lib/"*.a
do
    LIB_NAME="$(basename $LIB)"
    echo "LIPO_INPUT command find \"$THIN\" -name \"$LIB_NAME\""
    LIPO_INPUT=`find "$THIN" -name "$LIB_NAME"`
    lipo -create $LIPO_INPUT -output "$FAT/lib/$LIB_NAME" || exit 1
done
cp -rf "$THIN/$1/include" "$FAT"
