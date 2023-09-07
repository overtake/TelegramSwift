#!/bin/sh

# Only there to make jhbuild happy

if [ -z "$MESON" ]; then
    MESON=$(which meson)
fi
if [ -z "$MESON" ]; then
	echo "error: Meson not found."
	echo "Install meson to configure and build Pipewire. If meson" \
	     "is already installed, set the environment variable MESON" \
	     "to the binary's path."
	exit 1;
fi

mkdir -p build
$MESON setup "$@" build # use 'autogen.sh --reconfigure' to update
ln -sf build/Makefile Makefile
