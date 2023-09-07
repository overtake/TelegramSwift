#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "tg_owt::tg_owt" for configuration "Release"
set_property(TARGET tg_owt::tg_owt APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(tg_owt::tg_owt PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "C;CXX"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libtg_owt.a"
  )

list(APPEND _IMPORT_CHECK_TARGETS tg_owt::tg_owt )
list(APPEND _IMPORT_CHECK_FILES_FOR_tg_owt::tg_owt "${_IMPORT_PREFIX}/lib/libtg_owt.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
