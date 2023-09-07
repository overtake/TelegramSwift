add_library(libcrc32c OBJECT EXCLUDE_FROM_ALL)
init_target(libcrc32c)
add_library(tg_owt::libcrc32c ALIAS libcrc32c)

set(libcrc32c_loc ${third_party_loc}/crc32c/src)

configure_file(
    ${libcrc32c_loc}/src/crc32c_config.h.in
    ${PROJECT_BINARY_DIR}/include/crc32c/crc32c_config.h
)

nice_target_sources(libcrc32c ${libcrc32c_loc}
PRIVATE
    src/crc32c_portable.cc
    src/crc32c.cc
    include/crc32c/crc32c.h
    src/crc32c_arm64.h
    src/crc32c_internal.h
    src/crc32c_prefetch.h
    src/crc32c_read_le.h
    src/crc32c_round_up.h
    src/crc32c_sse42.h
    src/crc32c_sse42_check.h
    src/crc32c_arm64_check.h
)

target_sources(libcrc32c PRIVATE ${PROJECT_BINARY_DIR}/include/crc32c/crc32c_config.h)

target_include_directories(libcrc32c
PRIVATE
    ${libcrc32c_loc}/include
    ${PROJECT_BINARY_DIR}/include
)
