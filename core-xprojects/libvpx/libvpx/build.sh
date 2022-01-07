
set -e
set -x


SRC_DIR="$1"
BUILD_DIR=$(echo "$(cd "$(dirname "$3")"; pwd -P)/$(basename "$3")")



SOURCE_DIR="$BUILD_DIR/source"


pushd "$BUILD_DIR"


BUILD_ROOT="build"
CONFIGURE_ARGS="--disable-docs
                --disable-examples
                --disable-postproc
                --disable-webm-io
                --disable-vp9-highbitdepth
                --disable-vp9-postproc
                --disable-vp9-temporal-denoising
                --disable-unit-tests
                --enable-realtime-only
                --enable-multi-res-encoding"
DIST_DIR="_dist"
FRAMEWORK_DIR="VPX.framework"
FRAMEWORK_LIB="VPX.framework/VPX"
HEADER_DIR="${FRAMEWORK_DIR}/Headers/vpx"
SCRIPT_DIR="$SOURCE_DIR"
LIBVPX_SOURCE_DIR="$SOURCE_DIR"



ORIG_PWD="$(pwd)"



# Configures for the target specified by $1, and invokes make with the dist
# target using $DIST_DIR as the distribution output directory.
build_target() {

ARCH=$1
if [ "$1" = "arm64" ]; then
    local target="arm64-darwin20-gcc"
elif [ "$1" = "x86_64" ]; then
    local target="x86_64-darwin15-gcc"
else
  echo "Unsupported architecture $1"
  exit 1
fi

  local old_pwd="$(pwd)"
  local target_specific_flags=""

  case "${target}" in
    x86-*)
      target_specific_flags="--enable-pic"
      ;;
  esac

  mkdir "${ARCH}"
  cd "${ARCH}"
  cp -R ${LIBVPX_SOURCE_DIR}/* ./
  ./configure --target="${target}" \
    ${CONFIGURE_ARGS} ${EXTRA_CONFIGURE_ARGS} ${target_specific_flags} \

  export DIST_DIR
  make dist
  cd "${old_pwd}"
}

# Returns the preprocessor symbol for the target specified by $1.
target_to_preproc_symbol() {
  target="$1"
  case "${target}" in
    arm64-*)
      echo "__aarch64__"
      ;;
    armv7-*)
      echo "__ARM_ARCH_7A__"
      ;;
    x86_64-*)
      echo "__x86_64__"
      ;;
    *)
      echo "#error ${target} unknown/unsupported"
      return 1
      ;;
  esac
}

# Create a vpx_config.h shim that, based on preprocessor settings for the
# current target CPU, includes the real vpx_config.h for the current target.
# $1 is the list of targets.
create_vpx_framework_config_shim() {
  local targets="$1"
  local config_file="${HEADER_DIR}/vpx_config.h"
  local preproc_symbol=""
  local target=""
  local include_guard="VPX_FRAMEWORK_HEADERS_VPX_VPX_CONFIG_H_"

  local file_header="/*
 *  Copyright (c) The WebM project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */
/* GENERATED FILE: DO NOT EDIT! */
#ifndef ${include_guard}
#define ${include_guard}
#if defined"

  printf "%s" "${file_header}" > "${config_file}"
  for t in ${targets}; do
    if [ "$t" = "arm64" ]; then
        local target="arm64-darwin20-gcc"
    elif [ "$t" = "x86_64" ]; then
        local target="x86_64-darwin15-gcc"
    else
        echo "Unsupported architecture $1"
        exit 1
    fi
    preproc_symbol=$(target_to_preproc_symbol "${target}")
    printf " ${preproc_symbol}\n" >> "${config_file}"
    printf "#define VPX_FRAMEWORK_TARGET \"${target}\"\n" >> "${config_file}"
    printf "#include \"VPX/vpx/${target}/vpx_config.h\"\n" >> "${config_file}"
    printf "#elif defined" >> "${config_file}"
    mkdir "${HEADER_DIR}/${t}"
    cp -p "${BUILD_ROOT}/${t}/vpx_config.h" "${HEADER_DIR}/${t}"
  done

  # Consume the last line of output from the loop: We don't want it.
  sed -i.bak -e '$d' "${config_file}"
  rm "${config_file}.bak"

  printf "#endif\n\n" >> "${config_file}"
  printf "#endif  // ${include_guard}" >> "${config_file}"
}

# Configures and builds each target specified by $1, and then builds
# VPX.framework.
build_framework() {
  local lib_list=""
  local targets=$ARCHS
  local target=""
  local target_dist_dir=""

  # Clean up from previous build(s).
  rm -rf "${BUILD_ROOT}" "${FRAMEWORK_DIR}"

  # Create output dirs.
  mkdir -p "${BUILD_ROOT}"
  mkdir -p "${HEADER_DIR}"

  cd "${BUILD_ROOT}"

  for target in ${targets}; do
    build_target "${target}"
    target_dist_dir="${BUILD_ROOT}/${target}/${DIST_DIR}"
    local suffix="a"
    lib_list="${lib_list} ${target_dist_dir}/lib/libvpx.${suffix}"
  done

  cd "${ORIG_PWD}"

  # The basic libvpx API includes are all the same; just grab the most recent
  # set.
  cp -p "${target_dist_dir}"/include/vpx/* "${HEADER_DIR}"

  # Build the fat library.
  lipo -create ${lib_list} -output ${FRAMEWORK_DIR}/VPX

  # Create the vpx_config.h shim that allows usage of vpx_config.h from
  # within VPX.framework.
  create_vpx_framework_config_shim "${targets}"

  # Copy in vpx_version.h.
  cp -p "${BUILD_ROOT}/${target}/vpx_version.h" "${HEADER_DIR}"
}

build_framework "${TARGETS}"

popd
