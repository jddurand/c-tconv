#
# Multi-config generator, e.g. Visual Studio on Windows:
#
# cmake -S c-tconv -B c-tconv-build
# cmake --build c-tconv-build --config RelWithDebInfo
# ctest --test-dir c-tconv-build -C RelWithDebInfo
# Windows:
#   cmake --install c-tconv-build --config RelWithDebInfo --prefix %cd%/c-tconv-install
# Others:
#   cmake --install c-tconv-build --config RelWithDebInfo --prefix `pwd`/c-tconv-install
# cmake --build c-tconv-build --config RelWithDebInfo --target package
#
# Single-config generator, e.g. NMake Makefiles on Windows, Unix Makefiles on Linxu:
#
# cmake -S c-tconv -B c-tconv-build -DCMAKE_BUILD_TYPE=RelWithDebInfo
# cmake --build c-tconv-build
# ctest --test-dir c-tconv-build
# Windows:
#   cmake --install c-tconv-build --prefix %cd%/c-tconv-install
# Others:
#   cmake --install c-tconv-build --prefix `pwd`/c-tconv-install
# cmake --build c-tconv-build --target package
#
# Local tests done with: cmake -S c-tconv -B c-tconv-build -DCMAKE_HELPERS_DEBUG=OFF -DICU_ROOT=C:\icu4c-74_2-Win64-MSVC2019
#
cmake_minimum_required(VERSION 3.26.0 FATAL_ERROR)
project(tconv VERSION 1.0.87 LANGUAGES C CXX)
#
# Specific options
#
option(PREFER_STATIC_DEPENDENCIES "Prefer static dependencies" OFF)
message(STATUS "Prefer static dependencies: ${PREFER_STATIC_DEPENDENCIES}")
#
# Specific options
#
option(TCONV_USE_ICU    "Enable ICU plugin if found" OFF)
option(TCONV_USE_ICONV  "Enable ICONV plugin plugin" ON)
#
# Get library helper
#
include(FetchContent)
FetchContent_Declare(cmake-helpers GIT_REPOSITORY https://github.com/jddurand/cmake-helpers.git GIT_SHALLOW TRUE)
FetchContent_MakeAvailable(cmake-helpers)
#
# Dependencies
#
set(libtconv_depends)
set(libtconv_depends_ext)
set(libtconv_find_dependencies)
set(libtconv_extra_licenses)
#
# iconv: We always want to embed libiconv in tconv
#
set(libtconv_src src/tconv.c src/tconv/charset/tconv_charset_cchardet.c)
if(TCONV_USE_ICONV)
  set(libiconv_version 1.17)
  set(libiconv_file ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/tar/libiconv-${libiconv_version}.tar.gz)
  set(libiconv_url https://ftp.gnu.org/gnu/libiconv/libiconv-${libiconv_version}.tar.gz)
  set(ICONV_VERSION ${libiconv_version}) # For the inner add_subdirectory()
  cmake_helpers_depend(libiconv
    EXTERNALPROJECT_ADD_ARGS
      URL ${libiconv_file}
      PATCH_COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/cmake/iconv/CMakeLists.txt .
            COMMAND ${CMAKE_COMMAND} -E rm include/export.h # This file has nothing to do here -;
    CMAKE_ARGS -DICONV_VERSION=${libiconv_version}
    FIND FALSE
    CONFIGURE FALSE
    BUILD FALSE
    INSTALL FALSE
    MAKEAVAILABLE TRUE
    EXCLUDE_FROM_ALL TRUE
    EXPORT_HEADER_STATIC_DEFINE libiconv_STATIC # This is the default but we set it to be sure we control it
    SOURCE_DIR_OUTVAR libiconv_source_dir
  )
  #
  # We always use libiconv static objects regardless of PREFER_STATIC_DEPENDENCIES
  #
  list(APPEND libtconv_extra_licenses libiconv ${libiconv_source_dir}/COPYING)
  #
  # This hack of "PUBLIC BUILD_LOCAL_INTERFACE $<COMPILE_ONLY:xx_iface>" followed by "PUBLIC $<LINK_ONLY:xx>" is for having
  # xx compilation usage requirements forwarded to our targets, link with xx objects, without having to depend on xx export set.
  #
  add_library(libiconv_static_iface INTERFACE)
  target_link_libraries(libiconv_static_iface INTERFACE libiconv_static $<TARGET_OBJECTS:libiconv_static>)
  list(APPEND libtconv_depends_ext PRIVATE BUILD_LOCAL_INTERFACE $<COMPILE_ONLY:libiconv_static_iface>)
  list(APPEND libtconv_depends PRIVATE $<LINK_ONLY:libiconv_static_iface>)
  set(TCONV_HAVE_ICONV 1)
  set(ICONV_SECOND_ARGUMENT_IS_CONST FALSE)
  set(ICONV_CAN_TRANSLIT TRUE)
  set(ICONV_CAN_IGNORE TRUE)
  list(APPEND libtconv_src src/tconv/convert/tconv_convert_iconv.c)
endif()
#
# ICU : library dependency
#
if(TCONV_USE_ICU)
  find_package(ICU COMPONENTS uc i18n)
  if(ICU_FOUND)
    set(TCONV_HAVE_ICU 1)
    list(APPEND libtconv_src src/tconv/charset/tconv_charset_ICU.c src/tconv/convert/tconv_convert_ICU.c)
    list(APPEND libtconv_find_dependencies "ICU REQUIRED COMPONENTS uc i18n")
    list(APPEND libtconv_depends_ext PRIVATE BUILD_LOCAL_INTERFACE ICU::uc)
    list(APPEND libtconv_depends_ext PUBLIC LINK_ONLY ICU::uc)
    list(APPEND libtconv_depends_ext PRIVATE BUILD_LOCAL_INTERFACE ICU::i18n)
    list(APPEND libtconv_depends_ext PUBLIC LINK_ONLY ICU::i18n)
  else()
    message(WARNING "Option USE_ICU is ON but ICU is not found")
  endif()
endif()
#
# Paths: special case of ICU - we know that runtime paths on Windows for FindIcu.cmake are not available on Windows.
# Fortunately, ICU is always delivered with uconv executable, and all DLLs are in the same directory.
#
set(_test_environment)
if(WIN32 AND TCONV_HAVE_ICU AND ICU_UCONV_EXECUTABLE)
  cmake_path(GET ICU_UCONV_EXECUTABLE PARENT_PATH _parent_path)
  list(APPEND _test_environment ${_parent_path})
endif()
#
# Portable dlopen for Win32: we always want to embed dl in tconv
#
if(WIN32 AND NOT CYGWIN)
  set(dlfcn_win32_version 1.4.1)
  set(dlfcn_win32_file ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/tar/dlfcn-win32-${dlfcn_win32_version}.tar.gz)
  set(dlfcn_win32_url https://github.com/dlfcn-win32/dlfcn-win32/archive/refs/tags/v${dlfcn_win32_version}.tar.gz)
  set(DLFCN_WIN32_VERSION ${dlfcn_win32_version}) # For the inner add_subdirectory()
  cmake_helpers_depend(dlfcn_win32
    EXTERNALPROJECT_ADD_ARGS
      URL ${dlfcn_win32_file}
      PATCH_COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/cmake/dlfcn-win32/CMakeLists.txt .
    CMAKE_ARGS -DDLFCN_WIN32_VERSION=${dlfcn_win32_version}
    FIND FALSE
    CONFIGURE FALSE
    BUILD FALSE
    INSTALL FALSE
    MAKEAVAILABLE TRUE
    EXCLUDE_FROM_ALL TRUE
    SOURCE_DIR_OUTVAR dlfcn_win32_source_dir
  )
  #
  # We always use dlfcn_win32 static objects regardless of PREFER_STATIC_DEPENDENCIES
  #
  add_library(dl_static_iface INTERFACE)
  target_link_libraries(dl_static_iface INTERFACE dl_static $<TARGET_OBJECTS:dl_static>)
  list(APPEND libtconv_depends_ext PRIVATE BUILD_LOCAL_INTERFACE $<COMPILE_ONLY:dl_static_iface>)
  list(APPEND libtconv_depends PRIVATE $<LINK_ONLY:dl_static_iface>)
else()
  if(CMAKE_DL_LIBS)
    list(APPEND libtconv_depends PUBLIC ${CMAKE_DL_LIBS})
  else()
    message(WARNING "No library containing dlopen/dlclose")
  endif()
endif()
#
# Generic logger: library dependency
#
set(genericLogger_git https://github.com/jddurand/c-genericLogger.git)
cmake_helpers_depend(genericLogger
  EXTERNALPROJECT_ADD_ARGS GIT_REPOSITORY ${genericLogger_git} GIT_SHALLOW TRUE
  FIND_PACKAGE_ARGS REQUIRED CONFIG
)
list(APPEND libtconv_find_dependencies "genericLogger REQUIRED CONFIG")
if(PREFER_STATIC_DEPENDENCIES)
  list(APPEND libtconv_depends_ext PRIVATE BUILD_LOCAL_INTERFACE genericLogger::genericLogger_static)
  list(APPEND libtconv_depends_ext PUBLIC LINK_ONLY genericLogger::genericLogger_static)
else()
  list(APPEND libtconv_depends_ext PRIVATE BUILD_LOCAL_INTERFACE genericLogger::genericLogger)
  list(APPEND libtconv_depends_ext PUBLIC LINK_ONLY genericLogger::genericLogger)
endif()
#
# cchardet sources: embedded using source files
#
set(cchardet_tarball ${CMAKE_CURRENT_SOURCE_DIR}/3rdparty/tar/cchardet-1.0.0.tar.gz)
set(cchardet_workdir ${CMAKE_CURRENT_BINARY_DIR}/cchardet-1.0.0)
if(NOT EXISTS ${cchardet_workdir})
  message(STATUS "Unpacking ${cchardet_tarball}")
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E tar xzf ${cchardet_tarball}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
  )
  #
  # nspr-emu mess revisit
  # We will need common includes and sizes now - so let's call the macro doing that
  #
  message(STATUS "Suppress directory ${cchardet_workdir}/src/ext/libcharsetdetect/nspr-emu")
  execute_process(COMMAND ${CMAKE_COMMAND} -E remove_directory ${cchardet_workdir}/src/ext/libcharsetdetect/nspr-emu)
  message(STATUS "Generate directory ${cchardet_workdir}/src/ext/libcharsetdetect/nspr-emu")
  execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory ${cchardet_workdir}/src/ext/libcharsetdetect/nspr-emu)
  message(STATUS "Copying file ${CMAKE_CURRENT_SOURCE_DIR}/include/nsDebug.h.in to ${cchardet_workdir}/src/ext/libcharsetdetect/nspr-emu/nsDebug.h")
  execute_process(COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/include/nsDebug.h.in ${cchardet_workdir}/src/ext/libcharsetdetect/nspr-emu/nsDebug.h)
  message(STATUS "Copying file file ${CMAKE_CURRENT_SOURCE_DIR}/include/prmem.h.in to ${cchardet_workdir}/src/ext/libcharsetdetect/nspr-emu/prmem.h")
  execute_process(COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/include/prmem.h.in ${cchardet_workdir}/src/ext/libcharsetdetect/nspr-emu/prmem.h)
  message(STATUS "Suppress file ${cchardet_workdir}/src/ext/libcharsetdetect/nscore.h")
  execute_process(COMMAND ${CMAKE_COMMAND} -E remove -f ${cchardet_workdir}/src/ext/libcharsetdetect/nscore.h)
  message(STATUS "Generating file ${cchardet_workdir}/src/ext/libcharsetdetect/nscore.h using ${CMAKE_CURRENT_SOURCE_DIR}/include/nscore.h.in")
  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/include/nscore.h.in ${cchardet_workdir}/src/ext/libcharsetdetect/nscore.h)
endif()
file(GLOB ccharset_src
  ${cchardet_workdir}/src/ext/libcharsetdetect/mozilla/extensions/universalchardet/src/base/*.cpp
  ${cchardet_workdir}/src/ext/libcharsetdetect/charsetdetect.cpp
)
set(ccharset_inc
  ${cchardet_workdir}/src/ext/libcharsetdetect/mozilla/extensions/universalchardet/src/base
  ${cchardet_workdir}/src/ext/libcharsetdetect/nspr-emu
  ${cchardet_workdir}/src/ext/libcharsetdetect
)
add_library(cchardet_objs OBJECT ${ccharset_src})
target_include_directories(cchardet_objs PRIVATE ${ccharset_inc})
list(APPEND libtconv_depends_ext PRIVATE BUILD_LOCAL_INTERFACE cchardet_objs)
#
# optparse: embedded using source files
#
set(optparse_git https://github.com/skeeto/optparse.git)
cmake_helpers_depend(optparse
  EXTERNALPROJECT_ADD_ARGS
    GIT_REPOSITORY ${optparse_git}
    GIT_SHALLOW TRUE
  #
  # Setting FIND and INSTALL to FALSE guaranteed that we download the source and do nothing else
  #
  FIND FALSE
  CONFIGURE FALSE
  BUILD FALSE
  INSTALL FALSE
  MAKEAVAILABLE FALSE
  EXCLUDE_FROM_ALL TRUE
  #
  # ../. which means that these variables will always be set
  #
  SOURCE_DIR_OUTVAR optparse_source_dir
  BINARY_DIR_OUTVAR optparse_binary_dir
)
#
# Create library
#
cmake_helpers_library(tconv
  CONFIG_ARGS       include/tconv/internal/config.h.in include/tconv/internal/config.h
  PODS_AUTO         FALSE # We have several files with the same name README.pod, c.f. below
  SOURCES           ${libtconv_src}
  FIND_DEPENDENCIES ${libtconv_find_dependencies}
  DEPENDS           ${libtconv_depends}
  DEPENDS_EXT       ${libtconv_depends_ext}
  TARGETS_OUTVAR    targets
)
#
# Add ccharset_inc to tconv targets
#
foreach(target IN LISTS targets)
  target_include_directories(${target} PRIVATE ${ccharset_inc})
endforeach()
#
# With MSVC, it emits a lof of warnings we can ignore
#
if(MSVC)
  foreach(target IN LISTS targets)
    target_compile_options(${target} PRIVATE /wd4838) # warning C4838: conversion from 'int' to 'const PRInt16' requires a narrowing conversion
    target_compile_options(${target} PRIVATE /wd4067) # warning C4067: unexpected tokens following preprocessor directive - expected a newline
    target_compile_options(${target} PRIVATE /wd4068) # warning C4068: unknown pragma 'GCC'
  endforeach()
endif()
#
# PODs
#
cmake_helpers_pod(INPUT ${CMAKE_CURRENT_SOURCE_DIR}/include/README.pod NAME tconv SECTION 3)
cmake_helpers_pod(INPUT ${CMAKE_CURRENT_SOURCE_DIR}/include/tconv/README.pod NAME tconv_ext SECTION 3)
#
# EXEs
#
set(tconv_depends_ext)
set(tconv_depends)
if(PREFER_STATIC_DEPENDENCIES)
  list(APPEND tconv_depends PRIVATE genericLogger::genericLogger_static)
else()
  list(APPEND tconv_depends PRIVATE genericLogger::genericLogger)
endif()
cmake_helpers_exe(tconv
  SOURCES        bin/tconv.c
  DEPENDS        ${tconv_depends}
  DEPENDS_EXT    ${tconv_depends_ext}
  INSTALL        TRUE
  TEST           TRUE
  TEST_ARGS      -t UTF-16 -o tconv.tconv-UTF-16.c "${CMAKE_CURRENT_SOURCE_DIR}/src/tconv.c"
  TARGETS_OUTVAR tconv_targets
  ENVIRONMENT    ${_test_environment}
)
foreach(_target IN LISTS tconv_targets)
  target_compile_definitions(${_target} PRIVATE -DOPTPARSE_IMPLEMENTATION -DOPTPARSE_API=static)
  target_include_directories(${_target} PRIVATE ${optparse_source_dir})
  #
  # We know this will produce two targets: tconv_shared_exe and tconv_static_exe
  #
  if(_target STREQUAL "tconv_shared_exe")
    set_target_properties(${_target} PROPERTIES OUTPUT_NAME tconv)
  elseif(_target STREQUAL "tconv_static_exe")
    set_target_properties(${_target} PROPERTIES OUTPUT_NAME tconv_static)
  else()
    message(WARNING "Unexpected target ${_target}")
  endif()
  #
  # Specific to SunOs
  #
  if(CMAKE_C_COMPILER_ID STREQUAL SunPro)
    target_link_libraries(${_target} PUBLIC Crun)
  endif()
endforeach()
#
# Tests
#
include(CTest)
cmake_helpers_exe(tconvExample
  SOURCES        test/example.c
  INSTALL        FALSE
  TEST           TRUE
  TARGETS_OUTVAR example_targets
  ENVIRONMENT    ${_test_environment}
)
foreach(_target IN LISTS example_targets)
  #
  # Specific to SunOs
  #
  if(CMAKE_C_COMPILER_ID STREQUAL SunPro)
    target_link_libraries(${_target} PUBLIC Crun)
  endif()
endforeach()
#
# Package
#
cmake_helpers_package(
  EXTRA_LICENSES ${libtconv_extra_licenses}
)
