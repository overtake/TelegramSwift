include(CMakeFindDependencyMacro)
if (@absl_FOUND@)
    find_dependency(absl REQUIRED)
endif()
if (@Crc32c_FOUND@)
    find_dependency(Crc32c)
endif()

include("${CMAKE_CURRENT_LIST_DIR}/tg_owtTargets.cmake")
