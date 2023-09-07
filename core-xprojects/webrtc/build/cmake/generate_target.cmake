# This file is part of Desktop App Toolkit,
# a set of libraries for developing nice desktop applications.
#
# For license and copyright information please follow this link:
# https://github.com/desktop-app/legal/blob/master/LEGAL

function(generate_target parent_name postfix generated_timestamp generated_files gen_dst)
    add_custom_target(${parent_name}_${postfix} DEPENDS ${generated_timestamp})
    init_target_folder(${parent_name}_${postfix} "(gen)")
    add_dependencies(${parent_name} ${parent_name}_${postfix})
    target_sources(${parent_name} PRIVATE ${generated_files})
    target_include_directories(${parent_name} PRIVATE ${gen_dst})
    source_group("(gen)" FILES ${generated_files})
endfunction()
