include(CheckSymbolExists)

# Initialization:
set(is_x64 0)
set(is_x86 0)
set(is_aarch64 0)
set(is_arm  0)
set(is_arm8 0)
set(is_arm7 0)
set(arm_use_neon 0)

option(TG_OWT_ARCH_ARMV7_USE_NEON "Use NEON SIMD instructions when building for ARMv7" ON)


# Check for 64-bit x86 (aka x64):
check_symbol_exists(__x86_64   "stddef.h" HAVE_X64_DEF1)
check_symbol_exists(__x86_64__ "stddef.h" HAVE_X64_DEF2)
check_symbol_exists(__amd64    "stddef.h" HAVE_X64_DEF3)
check_symbol_exists(_M_X64     "stddef.h" HAVE_X64_DEF4)

if ((HAVE_X64_DEF1 OR HAVE_X64_DEF2) OR (HAVE_X64_DEF3 OR HAVE_X64_DEF4))
    message(STATUS "Processor architecture is 64-bit x86.")
    set(is_x64 1)
else()


# Check for 32-bit x86:
check_symbol_exists(__i386   "stddef.h" HAVE_I386_DEF1)
check_symbol_exists(__i386__ "stddef.h" HAVE_I386_DEF2)
check_symbol_exists(_M_IX86  "stddef.h" HAVE_I386_DEF3)

if ((HAVE_I386_DEF1 OR HAVE_I386_DEF2) OR HAVE_I386_DEF3)
    message(STATUS "Processor architecture is 32-bit x86.")
    set(is_x86 1)
else()


# Check for 64-bit ARM processors (aka aarch64):
# TODO: Add support for endianness checks (ARM is bi-endian).
check_symbol_exists(__aarch64__ "stddef.h" HAVE_AARCH64_DEF1)
check_symbol_exists(__ARM64__   "stddef.h" HAVE_AARCH64_DEF2)
check_symbol_exists(_M_ARM64    "stddef.h" HAVE_AARCH64_DEF3)

if ((HAVE_AARCH64_DEF1 OR HAVE_AARCH64_DEF2) OR HAVE_AARCH64_DEF3)
    message(STATUS "Processor architecture is 64-bit ARM.")
    set(is_aarch64 1)
    set(is_arm8 1)
    set(arm_use_neon 1)
else()


# Check for 32-bit ARM processors:
check_symbol_exists(__arm__           "stddef.h" HAVE_ARM_DEF1)
check_symbol_exists(__TARGET_ARCH_ARM "stddef.h" HAVE_ARM_DEF2)
check_symbol_exists(_M_ARM            "stddef.h" HAVE_ARM_DEF3)

if ((HAVE_ARM_DEF1 OR HAVE_ARM_DEF2) OR HAVE_ARM_DEF3)
    message(STATUS "Processor architecture is 32-bit ARM.")
    set(is_arm 1)

    # Check for the ARMv8 architecture:
    check_symbol_exists(__ARMv8__   "stddef.h" HAVE_ARMV8_DEF1)
    check_symbol_exists(__ARMv8_A__ "stddef.h" HAVE_ARMV8_DEF2)

    if (HAVE_ARMV8_DEF1 OR HAVE_ARMV8_DEF2)
        message(STATUS "ARM Architecture version is 8.")
        set(is_arm8 1)
        set(arm_use_neon 1)

    else()

    # Check for the ARMv7 architecture:
    check_symbol_exists(__ARM_ARCH_7__   "stddef.h" HAVE_ARMV7_DEF1)
    check_symbol_exists(__ARM_ARCH_7A__  "stddef.h" HAVE_ARMV7_DEF2)
    check_symbol_exists(__ARM_ARCH_7R__  "stddef.h" HAVE_ARMV7_DEF3)
    check_symbol_exists(__ARM_ARCH_7M__  "stddef.h" HAVE_ARMV7_DEF4)
    check_symbol_exists(__ARM_ARCH_7S__  "stddef.h" HAVE_ARMV7_DEF5)
    check_symbol_exists(_ARM_ARCH_7      "stddef.h" HAVE_ARMV7_DEF6)
    check_symbol_exists(__CORE_CORTEXA__ "stddef.h" HAVE_ARMV7_DEF7)

    if (((HAVE_ARMV7_DEF1 OR HAVE_ARMV7_DEF2) OR (HAVE_ARMV7_DEF3 OR HAVE_ARMV7_DEF4)) OR
        ((HAVE_ARMV7_DEF5 OR HAVE_ARMV7_DEF6) OR  HAVE_ARMV7_DEF7))

        message(STATUS "ARM Architecture version is 7.")
        set(is_arm7 1)

        # The NEON SIMD instructions are mandatory on Cortex-A8, but optional
        # on Cortex-A9; needs to be explicitly enabled in the toolchain.
        #
        if (TG_OWT_ARCH_ARMV7_USE_NEON)
            message(STATUS "NEON SIMD instructions enabled (can be disabled with -DTG_OWT_ARCH_ARMV7_USE_NEON=OFF).")
            set(arm_use_neon 1)

            if (WIN32)
                # TODO: Add the correct flags for Windows here.
            elseif (APPLE)
                # TODO: Add the correct flags for Apple devices here.
            else()
                set(CMAKE_C_FLAGS   "${CMAKE_C_FLAGS}   -mfpu=neon")
                set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mfpu=neon")
                set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -mfpu=neon")
            endif()
        else()
            message(STATUS "NEON SIMD instructions not used (can be enabled with -DTG_OWT_ARCH_ARMV7_USE_NEON=ON).")
        endif()
    else()
        message(STATUS "ARM Architecture version is 6 or lower.")

    endif() #armv7
    endif() #armv8

# TODO: Add support for other architectures.
else()
    message(WARNING "Unsupported CPU architecture.")

endif() # arm32
endif() # aarch64
endif() # x86
endif() # x64
