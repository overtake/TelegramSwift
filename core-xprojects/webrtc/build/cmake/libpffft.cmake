add_library(libpffft OBJECT EXCLUDE_FROM_ALL)
init_target(libpffft)
add_library(tg_owt::libpffft ALIAS libpffft)

set(libpffft_loc ${third_party_loc}/pffft/src)

nice_target_sources(libpffft ${libpffft_loc}
PRIVATE
    fftpack.c
    pffft.c
)

target_compile_definitions(libpffft
PRIVATE
    _USE_MATH_DEFINES
)

if (NOT is_x86 AND NOT is_x64 AND NOT arm_use_neon)
    target_compile_definitions(libpffft
    PRIVATE
        PFFFT_SIMD_DISABLE
    )
endif()

target_include_directories(libpffft
PUBLIC
    $<BUILD_INTERFACE:${libpffft_loc}>
    $<INSTALL_INTERFACE:${webrtc_includedir}/third_party/pffft/src>
)
