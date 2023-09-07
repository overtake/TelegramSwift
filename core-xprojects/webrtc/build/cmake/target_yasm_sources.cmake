# This file is part of Desktop App Toolkit,
# a set of libraries for developing nice desktop applications.
#
# For license and copyright information please follow this link:
# https://github.com/desktop-app/legal/blob/master/LEGAL

function(target_yasm_sources target_name src_loc)
    set(list ${ARGV})
    list(REMOVE_AT list 0 1)
    
    if(WIN32)
        set(yasm_binary ${third_party_loc}/yasm/binaries/win/yasm.exe)
        if (is_x86)
            set(flags
                -DPREFIX
                -fwin32
                -m
                x86
            )
        else()
            set(flags
                -fwin64
                -m
                amd64
            )
        endif()
        set(object_ext .obj)
    elseif (APPLE)
        set(yasm_binary yasm)
        set(flags
            -fmacho64
            -m
            amd64
        )
        set(object_ext .o)
    else()
        set(yasm_binary yasm)
        if (is_x86)
            set(flags
                -felf32
                -m
                x86
            )
        else()
            set(flags
                -DPIC
                -felf64
                -m
                amd64
            )
        endif()
        set(object_ext .o)
    endif()

    set(include_dirs "")
    set(defines "")
    set(processing "")
    set(full_object_list "")
    set(gen_dst ${CMAKE_CURRENT_BINARY_DIR}/gen)
    foreach (entry ${list})
        if (${entry} STREQUAL "INCLUDE_DIRECTORIES" OR ${entry} STREQUAL "DEFINES" OR ${entry} STREQUAL "SOURCES")
            if (NOT "${processing}" STREQUAL "SOURCES" OR "${entry}" STREQUAL "SOURCES")
                set(processing ${entry})
            else()
                message(FATAL_ERROR "Sources should go after all include directories and defines.")
            endif()
        elseif (${processing} STREQUAL "INCLUDE_DIRECTORIES")
            list(APPEND include_dirs "-I${entry}")
        elseif (${processing} STREQUAL "DEFINES")
            list(APPEND defines "-D${entry}")
        else()
            set(full_name ${src_loc}/${entry})
            set(object_name ${gen_dst}/${entry}${object_ext})

            get_filename_component(object_name_loc ${object_name} DIRECTORY)
            file(MAKE_DIRECTORY ${object_name_loc})

            set(command
                ${yasm_binary}
                ${flags}
                ${include_dirs}
                -I.
                ${defines}
                ${full_name}
                -o ${object_name}
            )

            add_custom_command(
            OUTPUT
                ${object_name}
            # COMMAND
            #     ${CMAKE_COMMAND} -E echo "${command}"
            COMMAND
                "${command}"
            DEPENDS
                ${full_name}
            COMMAND_EXPAND_LISTS VERBATIM)

            set_source_files_properties(${object_name} PROPERTIES EXTERNAL_OBJECT ON GENERATED ON)
            target_sources(${target_name} PRIVATE ${object_name})
            list(APPEND full_object_list ${object_name})
        endif()
    endforeach()
    
    set(${target_name}_yasm_objects ${full_object_list} PARENT_SCOPE)
endfunction()
