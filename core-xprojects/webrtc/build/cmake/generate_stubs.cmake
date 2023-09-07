# This file is part of Desktop App Toolkit,
# a set of libraries for developing nice desktop applications.
#
# For license and copyright information please follow this link:
# https://github.com/desktop-app/legal/blob/master/LEGAL

function(generate_stubs target_name extra_stub_header output_name sigs_file)
    find_package(Python REQUIRED)

    get_filename_component(sigs_file_name ${sigs_file} NAME_WLE)

    set(gen_dst ${CMAKE_CURRENT_BINARY_DIR}/gen)
    file(MAKE_DIRECTORY ${gen_dst})

    set(gen_timestamp ${gen_dst}/${sigs_file_name}_stubs.timestamp)
    set(gen_files
        ${gen_dst}/${output_name}.cc
        ${gen_dst}/modules/desktop_capture/linux/wayland/${output_name}.h
    )
    add_custom_command(
    OUTPUT
        ${gen_timestamp}
    BYPRODUCTS
        ${gen_files}
    COMMAND
        ${Python_EXECUTABLE}
        ${tools_loc}/generate_stubs/generate_stubs.py
        --intermediate_dir ${gen_dst}
        --output ${gen_dst}/modules/desktop_capture/linux/wayland
        --type posix_stubs
        --extra_stub_header ${extra_stub_header}
        --stubfile_name ${output_name}
        --path_from_source ${gen_dst}
        --path_from_source modules/desktop_capture/linux/wayland
        --logging-function "\"RTC_LOG(LS_VERBOSE)\""
        --logging-include "rtc_base/logging.h"
        ${sigs_file}
    COMMAND
        touch ${gen_timestamp}
    COMMENT "Generating stubs ${sigs_file} (${target_name})"
    DEPENDS
        ${tools_loc}/generate_stubs/generate_stubs.py
        ${extra_stub_header}
        ${sigs_file}
    )
    generate_target(${target_name} ${sigs_file_name}_stubs ${gen_timestamp} "${gen_files}" ${gen_dst})
endfunction()
