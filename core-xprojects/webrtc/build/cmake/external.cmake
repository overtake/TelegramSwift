# OpenSSL
set(TG_OWT_OPENSSL_INCLUDE_PATH "" CACHE STRING "Include path for openssl.")
function(link_openssl target_name)
    if (TG_OWT_PACKAGED_BUILD)
        find_package(OpenSSL REQUIRED)
        target_include_directories(${target_name} SYSTEM PRIVATE ${OPENSSL_INCLUDE_DIR})
        target_link_libraries(${target_name} PRIVATE ${OPENSSL_LIBRARIES})
    else()
        if (TG_OWT_OPENSSL_INCLUDE_PATH STREQUAL "")
            message(FATAL_ERROR "You should specify 'TG_OWT_OPENSSL_INCLUDE_PATH'.")
        endif()

        target_include_directories(${target_name} SYSTEM
        PRIVATE
            ${TG_OWT_OPENSSL_INCLUDE_PATH}
        )
    endif()
endfunction()

# Opus
set(TG_OWT_OPUS_INCLUDE_PATH "" CACHE STRING "Include path for opus.")
function(link_opus target_name)
    if (TG_OWT_PACKAGED_BUILD)
        find_package(PkgConfig REQUIRED)
        pkg_check_modules(OPUS REQUIRED opus)
        target_include_directories(${target_name} SYSTEM PRIVATE ${OPUS_INCLUDE_DIRS})
        target_link_libraries(${target_name} PRIVATE ${OPUS_LINK_LIBRARIES})
    else()
        if (TG_OWT_OPUS_INCLUDE_PATH STREQUAL "")
            message(FATAL_ERROR "You should specify 'TG_OWT_OPUS_INCLUDE_PATH'.")
        endif()

        target_include_directories(${target_name} SYSTEM
        PRIVATE
            ${TG_OWT_OPUS_INCLUDE_PATH}
        )
    endif()
endfunction()

# FFmpeg
set(TG_OWT_FFMPEG_INCLUDE_PATH "" CACHE STRING "Include path for ffmpeg.")
function(link_ffmpeg target_name)
    if (TG_OWT_PACKAGED_BUILD)
        find_package(PkgConfig REQUIRED)
        pkg_check_modules(AVCODEC REQUIRED libavcodec)
        pkg_check_modules(AVFORMAT REQUIRED libavformat)
        pkg_check_modules(AVUTIL REQUIRED libavutil)
        pkg_check_modules(SWSCALE REQUIRED libswscale)
        pkg_check_modules(SWRESAMPLE REQUIRED libswresample)
        target_include_directories(${target_name} SYSTEM
        PRIVATE
            ${AVCODEC_INCLUDE_DIRS}
            ${AVFORMAT_INCLUDE_DIRS}
            ${AVUTIL_INCLUDE_DIRS}
            ${SWSCALE_INCLUDE_DIRS}
            ${SWRESAMPLE_INCLUDE_DIRS}
        )
        target_link_libraries(${target_name}
        PRIVATE
            ${AVCODEC_LINK_LIBRARIES}
            ${AVFORMAT_LINK_LIBRARIES}
            ${AVUTIL_LINK_LIBRARIES}
            ${SWSCALE_LINK_LIBRARIES}
            ${SWRESAMPLE_LINK_LIBRARIES}
        )
    else()
        if (TG_OWT_FFMPEG_INCLUDE_PATH STREQUAL "")
            message(FATAL_ERROR "You should specify 'TG_OWT_FFMPEG_INCLUDE_PATH'.")
        endif()

        target_include_directories(${target_name} SYSTEM
        PRIVATE
            ${TG_OWT_FFMPEG_INCLUDE_PATH}
        )
    endif()
endfunction()

# libjpeg
set(TG_OWT_LIBJPEG_INCLUDE_PATH "" CACHE STRING "Include path for libjpeg.")
function(link_libjpeg target_name)
    if (TG_OWT_PACKAGED_BUILD)
        find_package(JPEG REQUIRED)
        target_include_directories(${target_name} SYSTEM PRIVATE ${JPEG_INCLUDE_DIRS})
        target_link_libraries(${target_name} PRIVATE ${JPEG_LIBRARIES})
    else()
        if (TG_OWT_LIBJPEG_INCLUDE_PATH STREQUAL "")
            message(FATAL_ERROR "You should specify 'TG_OWT_LIBJPEG_INCLUDE_PATH'.")
        endif()

        target_include_directories(${target_name} SYSTEM
        PRIVATE
            ${TG_OWT_LIBJPEG_INCLUDE_PATH}
            ${TG_OWT_LIBJPEG_INCLUDE_PATH}/src
        )
    endif()
endfunction()

# libabsl
# HINT: System abseil should be built with
# * -DCMAKE_CXX_STANDARD=17 on Linux
# * -DCMAKE_CXX_STANDARD=14 on macOS
function(link_libabsl target_name)
    if (TG_OWT_PACKAGED_BUILD)
        find_package(absl)
        set(absl_FOUND ${absl_FOUND} PARENT_SCOPE)
        if (absl_FOUND)
            target_link_libraries(${target_name}
            INTERFACE
                absl::algorithm_container
                absl::bind_front
                absl::config
                absl::core_headers
                absl::flat_hash_map
                absl::inlined_vector
                absl::flags
                absl::flags_parse
                absl::flags_usage
                absl::memory
                absl::optional
                absl::strings
                absl::synchronization
                absl::type_traits
                absl::variant
            )
        endif()
    endif()
    if (NOT absl_FOUND)
        target_link_libraries(${target_name} PRIVATE tg_owt::libabsl)
    endif()
endfunction()

# libopenh264
function(link_libopenh264 target_name)
    if (TG_OWT_PACKAGED_BUILD)
        find_package(PkgConfig REQUIRED)
        pkg_check_modules(LIBOPENH264 openh264)
        set(LIBOPENH264_FOUND ${LIBOPENH264_FOUND} PARENT_SCOPE)
        if (LIBOPENH264_FOUND)
            target_link_libraries(${target_name} PRIVATE ${LIBOPENH264_LINK_LIBRARIES})
            target_include_directories(${target_name} SYSTEM PRIVATE ${LIBOPENH264_INCLUDE_DIRS})
        endif()
    endif()
    if (NOT LIBOPENH264_FOUND)
        target_link_libraries(${target_name} PRIVATE tg_owt::libopenh264)
        target_include_directories(${target_name} SYSTEM PRIVATE ${libopenh264_loc}/include)
    endif()
endfunction()

# libvpx
set(TG_OWT_LIBVPX_INCLUDE_PATH "" CACHE STRING "Include path for libvpx.")
function(link_libvpx target_name)
    if (TG_OWT_PACKAGED_BUILD)
        find_package(PkgConfig REQUIRED)
        pkg_check_modules(LIBVPX REQUIRED vpx>=1.10.0)
        target_link_libraries(${target_name} PRIVATE ${LIBVPX_LINK_LIBRARIES})
        target_include_directories(${target_name} SYSTEM PRIVATE ${LIBVPX_INCLUDE_DIRS})
    else()
        if (TG_OWT_LIBVPX_INCLUDE_PATH STREQUAL "")
            message(FATAL_ERROR "You should specify 'TG_OWT_LIBVPX_INCLUDE_PATH'.")
        endif()

        target_include_directories(${target_name} SYSTEM
        PRIVATE
            ${TG_OWT_LIBVPX_INCLUDE_PATH}
        )
    endif()
endfunction()

function(link_glib target_name)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(GLIB2 REQUIRED glib-2.0)
    pkg_check_modules(GOBJECT REQUIRED gobject-2.0)
    pkg_check_modules(GIO REQUIRED gio-2.0)
    pkg_check_modules(GIO_UNIX REQUIRED  gio-unix-2.0)
    target_include_directories(${target_name} SYSTEM
    PRIVATE
        ${GIO_UNIX_INCLUDE_DIRS}
        ${GIO_INCLUDE_DIRS}
        ${GOBJECT_INCLUDE_DIRS}
        ${GLIB2_INCLUDE_DIRS}
    )
    if (TG_OWT_PACKAGED_BUILD)
        target_link_libraries(${target_name}
        PRIVATE
            ${GIO_UNIX_LINK_LIBRARIES}
            ${GIO_LINK_LIBRARIES}
            ${GOBJECT_LINK_LIBRARIES}
            ${GLIB2_LINK_LIBRARIES}
        )
    endif()
endfunction()

# x11
function(link_x11 target_name)
    if (TG_OWT_PACKAGED_BUILD)
        find_package(X11 REQUIRED COMPONENTS Xcomposite Xdamage Xext Xfixes Xrender Xrandr Xtst)
        target_include_directories(${target_name} SYSTEM
        PRIVATE
            ${X11_X11_INCLUDE_PATH}
            ${X11_Xlib_INCLUDE_PATH}
            ${X11_Xcomposite_INCLUDE_PATH}
            ${X11_Xdamage_INCLUDE_PATH}
            ${X11_Xext_INCLUDE_PATH}
            ${X11_Xfixes_INCLUDE_PATH}
            ${X11_Xrender_INCLUDE_PATH}
            ${X11_Xrandr_INCLUDE_PATH}
            ${X11_Xtst_INCLUDE_PATH}
        )
        target_link_libraries(${target_name}
        PRIVATE
            ${X11_X11_LIB}
            ${X11_Xcomposite_LIB}
            ${X11_Xdamage_LIB}
            ${X11_Xext_LIB}
            ${X11_Xfixes_LIB}
            ${X11_Xrender_LIB}
            ${X11_Xrandr_LIB}
            ${X11_Xtst_LIB}
        )
    endif()
endfunction()

# PipeWire
function(link_pipewire target_name only_include_dirs)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(PIPEWIRE REQUIRED libpipewire-0.3)
    target_include_directories(${target_name} SYSTEM PRIVATE ${PIPEWIRE_INCLUDE_DIRS})
    if (NOT only_include_dirs)
        target_link_libraries(${target_name} PRIVATE ${PIPEWIRE_LINK_LIBRARIES})
    endif()
endfunction()

# Alsa
function(link_libalsa target_name)
    if (TG_OWT_PACKAGED_BUILD)
        find_package(ALSA REQUIRED)
        target_include_directories(${target_name} SYSTEM PRIVATE ${ALSA_INCLUDE_DIRS})
    endif()
endfunction()

# PulseAudio
function(link_libpulse target_name)
    if (TG_OWT_PACKAGED_BUILD)
        find_package(PkgConfig REQUIRED)
        pkg_check_modules(PULSE REQUIRED libpulse)
        target_include_directories(${target_name} SYSTEM PRIVATE ${PULSE_INCLUDE_DIRS})
    endif()
endfunction()

# dl
function(link_dl target_name)
    if (TG_OWT_PACKAGED_BUILD)
        target_link_libraries(${target_name} PRIVATE ${CMAKE_DL_LIBS})
    endif()
endfunction()
