#
# Multi-config generator, e.g. Visual Studio on Windows:
#
# cmake -S dlfcn-win32 -B dlfcn-win32-build
# cmake --build dlfcn-win32-build --config RelWithDebInfo
# ctest --test-dir dlfcn-win32-build -C RelWithDebInfo
# Windows:
#   cmake --install dlfcn-win32-build --config RelWithDebInfo --prefix %cd%/dlfcn-win32-install
# Others:
#   cmake --install dlfcn-win32-build --config RelWithDebInfo --prefix `pwd`/dlfcn-win32-install
# cmake --build dlfcn-win32-build --config RelWithDebInfo --target package
#
# Single-config generator, e.g. NMake Makefiles on Windows, Unix Makefiles on Linxu:
#
# cmake -S dlfcn-win32 -B dlfcn-win32-build -DCMAKE_BUILD_TYPE=RelWithDebInfo
# cmake --build dlfcn-win32-build
# ctest --test-dir dlfcn-win32-build
# Windows:
#   cmake --install dlfcn-win32-build --prefix %cd%/dlfcn-win32-install
# Others:
#   cmake --install dlfcn-win32-build --prefix `pwd`/dlfcn-win32-install
# cmake --build dlfcn-win32-build --target package
#
cmake_minimum_required(VERSION 3.26.0 FATAL_ERROR)
if(NOT DEFINED DLFCN_WIN32_VERSION)
  message(FATAL_ERROR "Missing -DDLFCN_WIN32_VERSION=<the version>")
endif()
project(dlfcn_win32 VERSION ${DLFCN_WIN32_VERSION} LANGUAGES C)
#
# Check we are WIN32
#
if(NOT WIN32)
  message(FATAL_ERROR "Not on a WIN32 host")
endif()
#
# Get library helper
#
include(FetchContent)
FetchContent_Declare(cmake-helpers GIT_REPOSITORY https://github.com/jddurand/cmake-helpers.git GIT_SHALLOW TRUE)
FetchContent_MakeAvailable(cmake-helpers)
#
# Create library
#
cmake_helpers_library(dl
  SOURCES_BASE_DIRS                   ${PROJECT_SOURCE_DIR}/src
  HEADERS_BASE_DIRS                   ${PROJECT_SOURCE_DIR}/src
  EXPORT_HEADER_SHARED_EXPORTS_DEFINE -DDLFCN_WIN32_EXPORTS
  SHARED_PUBLIC_DEFINES               -DDLFCN_WIN32_SHARED
)
#
# Tests
#
include(CTest)
add_library(testdll SHARED tests/testdll.c)
add_library(testdll2 SHARED tests/testdll2.c)
target_link_libraries(testdll2 dlfcn_win32)
add_library(testdll3 SHARED tests/testdll3.c)
cmake_helpers_exe(t_dlfcn
  SOURCES        tests/test.c
  INSTALL        FALSE
  TEST           TRUE
)
#
# test-dladdr needs hook that are available only with MSVC or linkers that support the -Wl syntax
#
if(MSVC OR (CMAKE_C_COMPILER_ID MATCHES Clang) OR (CMAKE_C_COMPILER_ID MATCHES GNU))
  cmake_helpers_exe(test-dladdr
    SOURCES        tests/test-dladdr.c
    INSTALL        FALSE
    TEST           TRUE
    TARGETS_OUTVAR targets
  )
  foreach(target IN LISTS targets)
    if(target STREQUAL "test-dladdr_static_exe")
      if(MSVC)
	set_property(TARGET ${target} APPEND_STRING PROPERTY LINK_FLAGS "/EXPORT:dlopen /EXPORT:dladdr")
      else()
        set_property(TARGET ${target} APPEND_STRING PROPERTY LINK_FLAGS "-Wl,--export-all-symbols")
      endif()
    endif()
  endforeach()
endif()
#
# Package
#
cmake_helpers_package(
  LICENSE ${PROJECT_SOURCE_DIR}/COPYING
)
