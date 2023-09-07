#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

while getopts ":b:v:" opt; do
	case ${opt} in
		b)
			BUILDDIR=${OPTARG}
			;;
		v)
			VERSION=${OPTARG}
			;;
		\?)
			echo "Invalid option: -${OPTARG}"
			exit 1
			;;
		:)
			echo "Option -${OPTARG} requires an argument"
			exit 1
			;;
	esac
done

if [ -z "${BUILDDIR}" ]; then
	BUILDDIR=${SCRIPT_DIR}/build
	echo "Using default build directory: ${BUILDDIR}"
fi

if [ ! -d "${BUILDDIR}" ]; then
	echo "Invalid build directory: ${BUILDDIR}"
	exit 1
fi

# the config file read by the daemon
export PIPEWIRE_CONFIG_DIR="${BUILDDIR}/src/daemon"
# the directory with SPA plugins
export SPA_PLUGIN_DIR="${BUILDDIR}/spa/plugins"
# the directory with pipewire modules
export PIPEWIRE_MODULE_DIR="${BUILDDIR}/src/modules"
export PATH="${BUILDDIR}/src/daemon:${BUILDDIR}/src/tools:${BUILDDIR}/src/examples:${PATH}"
export LD_LIBRARY_PATH="${BUILDDIR}/pipewire-pulseaudio/src/:${BUILDDIR}/src/pipewire/:${BUILDDIR}/pipewire-jack/src/${LD_LIBRARY_PATH+":$LD_LIBRARY_PATH"}"
export GST_PLUGIN_PATH="${BUILDDIR}/src/gst/${GST_PLUGIN_PATH+":${GST_PLUGIN_PATH}"}"
# the directory with card profiles and paths
export ACP_PATHS_DIR="${SCRIPT_DIR}/spa/plugins/alsa/mixer/paths"
export ACP_PROFILES_DIR="${SCRIPT_DIR}/spa/plugins/alsa/mixer/profile-sets"

# FIXME: find a nice, shell-neutral way to specify a prompt
${SHELL}
