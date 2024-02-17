#
# Multi-config generator, e.g. Visual Studio on Windows:
#
# cmake -S c-iconv -B c-iconv-build
# cmake --build c-iconv-build --config RelWithDebInfo
# ctest --test-dir c-iconv-build -C RelWithDebInfo
# Windows:
#   cmake --install c-iconv-build --config RelWithDebInfo --prefix %cd%/c-iconv-install
# Others:
#   cmake --install c-iconv-build --config RelWithDebInfo --prefix `pwd`/c-iconv-install
# cmake --build c-iconv-build --config RelWithDebInfo --target package
#
# Single-config generator, e.g. NMake Makefiles on Windows, Unix Makefiles on Linxu:
#
# cmake -S c-iconv -B c-iconv-build -DCMAKE_BUILD_TYPE=RelWithDebInfo
# cmake --build c-iconv-build
# ctest --test-dir c-iconv-build
# Windows:
#   cmake --install c-iconv-build --prefix %cd%/c-iconv-install
# Others:
#   cmake --install c-iconv-build --prefix `pwd`/c-iconv-install
# cmake --build c-iconv-build --target package
#
# Note: We voluntarily skip relation and the support of wchar.
#       If you want to enable relocation, on Windows, you should apply https://github.com/microsoft/vcpkg/blob/master/ports/libiconv/0004-ModuleFileName.patch
#       If you want to enable wchar, on Windows, you should apply https://github.com/microsoft/vcpkg/blob/master/ports/libiconv/0002-Config-for-MSVC.patch
#
cmake_minimum_required(VERSION 3.26.0 FATAL_ERROR)
if(NOT DEFINED ICONV_VERSION)
  message(FATAL_ERROR "Missing -DICONV_VERSION=<the version>")
endif()
project(libiconv VERSION ${ICONV_VERSION} LANGUAGES C)
option(WITH_ICONV_CONST "use a const in iconv" OFF)
option(WITHOUT_I18N "do never depend on libintl in iconv_no_i18n" OFF)
option(WITH_NLS "gettext() hooks in iconv binaries if possible" ON)
#
# Get library helper
#
include(FetchContent)
if("x$ENV{CMAKE_HELPERS_DEPEND_CMAKE_HELPERS_FILE}" STREQUAL "x")
  FetchContent_Declare(cmake-helpers GIT_REPOSITORY https://github.com/jddurand/cmake-helpers.git GIT_SHALLOW TRUE)
else()
  FetchContent_Declare(cmake-helpers URL $ENV{CMAKE_HELPERS_DEPEND_CMAKE_HELPERS_FILE})
endif()
FetchContent_MakeAvailable(cmake-helpers)
#
# Dependencies
#
set(libiconv_depends)
#
# ========
# config.h
# ========
#
# Read config.h.in and replace all lines starting with #undef by #cmakedefine, save that in config.h.in.cmake
# We locate the cases where the define should always exist and have a replacement, e.g.:
# ICONV_CONST
# We locate the cases where the define should always exist and be 0 or 1, e.g.:
# HAVE_WCRTOMB
# HAVE_MBRTOWC
# ENABLE_EXTRA
# Every HAVE_xxx
# else we use the #cmakedefine convention
#
file(READ ${CMAKE_CURRENT_SOURCE_DIR}/config.h.in _config_h_in)
foreach(_need_replacement ICONV_CONST)
  string(REGEX REPLACE "\n#undef[ \t]+${_need_replacement}" "\n#cmakedefine ${_need_replacement} @${_need_replacement}@" _config_h_in "${_config_h_in}")
endforeach()
foreach(_need_boolean HAVE_WCRTOMB HAVE_MBRTOWC ENABLE_EXTRA WORDS_LITTLEENDIAN)
  string(REGEX REPLACE "\n#undef[ \t]+${_need_boolean}" "\n#cmakedefine01 ${_need_boolean}" _config_h_in "${_config_h_in}")
endforeach()
string(REGEX REPLACE "\n#undef[ \t]+HAVE_([a-zA-Z0-9_]+)" "\n#cmakedefine01 HAVE_\\1" _config_h_in "${_config_h_in}")
string(REGEX REPLACE "\n#undef" "\n#cmakedefine" _config_h_in "${_config_h_in}")
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/config.h.in.cmake ${_config_h_in})
#
# We replace only @variables@ that are relevent to iconv source, we ignore gnulib etc.
#
include(CheckIncludeFile)
include(CheckSymbolExists)
include(TestBigEndian)
#
# DLL_VARIABLE: nothing - we replace all export hacks with CMake's libiconv_EXPORT
#
set(DLL_VARIABLE)
#
# #ifdef/#ifndef ICONV_CONST
#
if(WITH_ICONV_CONST)
  set(ICONV_CONST const)
else()
  set(ICONV_CONST " ")
endif()
#
# #ifdef/#ifndef NO_I18N
#
if(WITHOUT_I18N)
  set(NO_I18N 1)
else()
  include(FindIntl)
  if(NOT Intl_FOUND)
    set(NO_I18N 1)
  else()
    set(NO_I18N 0)
    if(Intl_LIBRARY)
      list(APPEND libiconv_depends PUBLIC ${Intl_LIBRARY})
    endif()
  endif()
endif()
#
# #if HAVE_WCHAR_T
#
if(FALSE)
  check_include_file("wchar.h" HAVE_WCHAR_H)
  if(HAVE_WCHAR_H)
    set(HAVE_WCHAR_H 1)
    set(CMAKE_EXTRA_INCLUDE_FILES_BACKUP ${CMAKE_EXTRA_INCLUDE_FILES})
    list(APPEND CMAKE_EXTRA_INCLUDE_FILES wchar.h)
    check_type_size("wchar_t" SIZEOF_WCHAR_T)
    set(CMAKE_EXTRA_INCLUDE_FILES ${CMAKE_EXTRA_INCLUDE_FILES_BACKUP})
    if(SIZEOF_WCHAR_T)
      set(HAVE_WCHAR_T 1)
    else()
      set(HAVE_WCHAR_T 0)
    endif()
  else()
    set(HAVE_WCHAR_H 0)
    set(HAVE_WCHAR_T 0)
  endif()
else()
  set(HAVE_WCHAR_H 0)
  set(HAVE_WCHAR_T 0)
endif()
#
# #if O_BINARY
#
check_include_file("fcntl.h" HAVE_FCNTL_H)
if(HAVE_FCNTL_H)
  check_symbol_exists("_O_BINARY" "fcntl.h" HAVE__O_BINARY)
  if(HAVE__O_BINARY)
    set(O_BINARY 1)
  else()
    set(O_BINARY 0)
  endif()
else()
  set(O_BINARY 0)
endif()
#
# #if HAVE_SETLOCALE
#
check_include_file("locale.h" HAVE_LOCALE_H)
if(HAVE_LOCALE_H)
  check_symbol_exists(setlocale "locale.h" HAVE_SETLOCALE)
  if(HAVE_SETLOCALE)
    set(HAVE_SETLOCALE 1)
  else()
    set(HAVE_SETLOCALE 0)
  endif()
else()
  set(HAVE_SETLOCALE 0)
endif()
#
# ENABLE_NLS
#
if(NOT WITH_NLS)
  set(ENABLE_NLS 0)
else()
  if(NOT HAVE_SETLOCALE)
    set(ENABLE_NLS 0)
  else()
    check_symbol_exists(bindtextdomain "libintl.h" HAVE_BINDTEXTDOMAIN)
    if(HAVE_BINDTEXTDOMAIN)
      set(ENABLE_NLS 1)
    else()
      set(ENABLE_NLS 0)
    endif()
  endif()
endif()
#
# HAVE_LANGINFO_CODESET
#
#
# Check nl_langinfo
#
try_compile(_compile_result SOURCE_FROM_CONTENT _try.c [[
#include <stdlib.h>
#include <langinfo.h>
int main(int ac, char **av)
{
  char *cs = nl_langinfo(CODESET);
  exit(0);
}
]]
)
if(_compile_result)
  set(HAVE_LANGINFO_CODESET 1)
else()
  set(HAVE_LANGINFO_CODESET 0)
endif()
#
# Check getc_unlocked
#
check_symbol_exists(getc_unlocked "stdio.h" HAVE_DECL_GETC_UNLOCKED)
if(HAVE_DECL_GETC_UNLOCKED)
  set(HAVE_DECL_GETC_UNLOCKED 1)
else()
  set(HAVE_DECL_GETC_UNLOCKED 0)
endif()
#
# Check endianness
#
test_big_endian(IS_BIG_ENDIAN)
if(NOT IS_BIG_ENDIAN)
  set(WORDS_LITTLEENDIAN 1)
else()
  set(WORDS_LITTLEENDIAN 0)
endif()
#
# Enable all iconv extras
#
set(ENABLE_EXTRA 1)
#
# Generate config.h
#
configure_file(${CMAKE_CURRENT_BINARY_DIR}/config.h.in.cmake ${CMAKE_CURRENT_BINARY_DIR}/include/internal/config.h @ONLY)
include_directories(${CMAKE_CURRENT_BINARY_DIR}/include/internal)
#
# =======
# iconv.h
# =======
#
# iconv.h.build.in contains unfortunately a bloc that would be hard to remove with a true patch.
# iconv.h.in is almost perfect: we just replace extern by extern [letter] by extern libiconv_EXPORT [a-ZA-Z_]
#
# In this file we replace:
#
# #define _LIBICONV_H
# by
# #define _LIBICONV_H
# include <libiconv/export.h>
#
# extern [a-ZA-Z_]
# by
# extern libiconv_EXPORT [a-ZA-Z_]
#
# @EILSEQ@
# by
# ENOENT
#
# @DLL_VARIABLE@
# by
# libiconv_EXPORT
#
file(READ ${CMAKE_CURRENT_SOURCE_DIR}/include/iconv.h.in _iconv_h_in)
string(REPLACE "#define _LIBICONV_H" "#define _LIBICONV_H\n#include <libiconv/export.h>\n" _iconv_h_in "${_iconv_h_in}")
string(REGEX REPLACE "\nextern[ \t]+([a-zA-Z_])" "\nextern libiconv_EXPORT \\1" _iconv_h_in "${_iconv_h_in}")
string(REPLACE "LIBICONV_DLL_EXPORTED" "libiconv_EXPORT" _iconv_h_in "${_iconv_h_in}")
string(REPLACE "@EILSEQ@" "ENOENT" _iconv_h_in "${_iconv_h_in}")
string(REPLACE "@DLL_VARIABLE@" "libiconv_EXPORT" _iconv_h_in "${_iconv_h_in}")
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/include/iconv.h.in.cmake "${_iconv_h_in}")
#
# Variables that will be replaced:
# @ICONV_CONST@ : c.f. upper
# @USE_MBSTATE_T@ : set to 1 if(HAVE_WCRTOMB || HAVE_MBRTOWC)
# @BROKEN_WCHAR_H@
#
if(HAVE_WCHAR_H)
  check_symbol_exists(wcrtomb "wchar.h" HAVE_WCRTOMB)
  check_symbol_exists(mbrtowc "wchar.h" HAVE_MBRTOWC)
  if(HAVE_WCRTOMB OR HAVE_MBRTOWC)
    set(USE_MBSTATE_T 1)
  else()
    set(USE_MBSTATE_T 0)
  endif()
  file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/broken_wchar.c [[
#include <wchar.h>
wchar_t w;
]])
  try_compile(_compile_result SOURCE_FROM_CONTENT _try.c "#include <wchar.h>\nwchar_t w;\n")
  if(_compile_result)
    message(STATUS "Checking if <wchar.h> is broken - no")
    set(BROKEN_WCHAR_H 0)
  else()
    message(STATUS "Checking if <wchar.h> is broken - yes")
    set(BROKEN_WCHAR_H 1)
  endif()
else()
  set(HAVE_WCRTOMB 0)
  set(HAVE_MBRTOWC 0)
  set(USE_MBSTATE_T 0)
  set(BROKEN_WCHAR_H 0) # Not used if NOT USE_MBSTATE_T
endif()
#
# Generate iconv.h
#
configure_file(${CMAKE_CURRENT_BINARY_DIR}/include/iconv.h.in.cmake ${CMAKE_CURRENT_BINARY_DIR}/include/iconv.h @ONLY)
#
# ==============
# localcharset.h (nothing to get configured in it btw)
# ==============
#
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/libcharset/include/localcharset.h.in ${CMAKE_CURRENT_BINARY_DIR}/libcharset/include/localcharset.h @ONLY)
include_directories(${CMAKE_CURRENT_BINARY_DIR}/libcharset/include)
#
# With MSVC, iconv emits a lot of warnings we can ignore
#
if(MSVC)
  add_compile_options(/wd4311)
endif()
#
# Create library
#
cmake_helpers_library(libiconv
  SOURCES libcharset/lib/localcharset.c lib/relocatable.c lib/iconv.c
  DEPENDS ${libiconv_depends}

)
#
# Package
#
cmake_helpers_package(
  LICENSE ${PROJECT_SOURCE_DIR}/COPYING
)
