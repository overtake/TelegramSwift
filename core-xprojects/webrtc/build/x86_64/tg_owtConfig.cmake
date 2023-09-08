include(CMakeFindDependencyMacro)
if ()
    find_dependency(absl REQUIRED)
endif()
if ()
    find_dependency(Crc32c)
endif()

include("${CMAKE_CURRENT_LIST_DIR}/tg_owtTargets.cmake")
