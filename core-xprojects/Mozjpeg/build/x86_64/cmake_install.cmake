# Install script for directory: /Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/opt/mozjpeg")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "TRUE")
endif()

# Set default install directory permissions.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "/Applications/Xcode_14_0_1.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/objdump")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/Users/mikerenoir/projects/Telegram-macOS/Telegram/core-xprojects/Mozjpeg/build/x86_64/libturbojpeg.a")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libturbojpeg.a" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libturbojpeg.a")
    execute_process(COMMAND "/Applications/Xcode_14_0_1.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libturbojpeg.a")
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE PROGRAM RENAME "tjbench" FILES "/Users/mikerenoir/projects/Telegram-macOS/Telegram/core-xprojects/Mozjpeg/build/x86_64/tjbench-static")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include" TYPE FILE FILES "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/turbojpeg.h")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/Users/mikerenoir/projects/Telegram-macOS/Telegram/core-xprojects/Mozjpeg/build/x86_64/libjpeg.a")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libjpeg.a" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libjpeg.a")
    execute_process(COMMAND "/Applications/Xcode_14_0_1.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libjpeg.a")
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE PROGRAM RENAME "cjpeg" FILES "/Users/mikerenoir/projects/Telegram-macOS/Telegram/core-xprojects/Mozjpeg/build/x86_64/cjpeg-static")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE PROGRAM RENAME "djpeg" FILES "/Users/mikerenoir/projects/Telegram-macOS/Telegram/core-xprojects/Mozjpeg/build/x86_64/djpeg-static")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE PROGRAM RENAME "jpegtran" FILES "/Users/mikerenoir/projects/Telegram-macOS/Telegram/core-xprojects/Mozjpeg/build/x86_64/jpegtran-static")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE EXECUTABLE FILES "/Users/mikerenoir/projects/Telegram-macOS/Telegram/core-xprojects/Mozjpeg/build/x86_64/rdjpgcom")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/rdjpgcom" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/rdjpgcom")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/Applications/Xcode_14_0_1.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/strip" -u -r "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/rdjpgcom")
    endif()
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE EXECUTABLE FILES "/Users/mikerenoir/projects/Telegram-macOS/Telegram/core-xprojects/Mozjpeg/build/x86_64/wrjpgcom")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/wrjpgcom" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/wrjpgcom")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "/Applications/Xcode_14_0_1.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/strip" -u -r "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/wrjpgcom")
    endif()
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/doc" TYPE FILE FILES
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/README.ijg"
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/README.md"
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/example.txt"
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/tjexample.c"
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/libjpeg.txt"
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/structure.txt"
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/usage.txt"
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/wizard.txt"
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/LICENSE.md"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/man/man1" TYPE FILE FILES
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/cjpeg.1"
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/djpeg.1"
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/jpegtran.1"
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/rdjpgcom.1"
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/wrjpgcom.1"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/pkgconfig" TYPE FILE FILES
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/core-xprojects/Mozjpeg/build/x86_64/pkgscripts/libjpeg.pc"
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/core-xprojects/Mozjpeg/build/x86_64/pkgscripts/libturbojpeg.pc"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include" TYPE FILE FILES
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/core-xprojects/Mozjpeg/build/x86_64/jconfig.h"
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/jerror.h"
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/jmorecfg.h"
    "/Users/mikerenoir/projects/Telegram-macOS/Telegram/submodules/telegram-ios/third-party/mozjpeg/mozjpeg/jpeglib.h"
    )
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for each subdirectory.
  include("/Users/mikerenoir/projects/Telegram-macOS/Telegram/core-xprojects/Mozjpeg/build/x86_64/simd/cmake_install.cmake")
  include("/Users/mikerenoir/projects/Telegram-macOS/Telegram/core-xprojects/Mozjpeg/build/x86_64/md5/cmake_install.cmake")

endif()

if(CMAKE_INSTALL_COMPONENT)
  set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INSTALL_COMPONENT}.txt")
else()
  set(CMAKE_INSTALL_MANIFEST "install_manifest.txt")
endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
file(WRITE "/Users/mikerenoir/projects/Telegram-macOS/Telegram/core-xprojects/Mozjpeg/build/x86_64/${CMAKE_INSTALL_MANIFEST}"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
