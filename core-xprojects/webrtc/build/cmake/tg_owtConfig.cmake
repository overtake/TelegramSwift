if (@absl_FOUND@)
    include(CMakeFindDependencyMacro)
    find_dependency(absl REQUIRED)
endif()

include("${CMAKE_CURRENT_LIST_DIR}/tg_owtTargets.cmake")
