if(CMAKE_CXX_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC" AND CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
  get_filename_component(_CLANG_BIN_DIR "${CMAKE_CXX_COMPILER}" DIRECTORY)
  set(CMAKE_CXX_COMPILER_CLANG_SCAN_DEPS "${_CLANG_BIN_DIR}/clang-scan-deps.exe")
  string(CONCAT CMAKE_CXX_SCANDEP_SOURCE
    "\"${CMAKE_CXX_COMPILER_CLANG_SCAN_DEPS}\""
    " -format=p1689"
    " --"
    " <CMAKE_CXX_COMPILER> <DEFINES> <INCLUDES> <FLAGS>"
    " -x c++ <SOURCE> -c"
    " -clang:-o -clang:<OBJECT>"
    " -clang:-MT -clang:<DYNDEP_FILE>"
    " -clang:-MD -clang:-MF -clang:<DEP_FILE>"
    " > <DYNDEP_FILE>.tmp"
    " && \"${CMAKE_COMMAND}\" -E rename <DYNDEP_FILE>.tmp <DYNDEP_FILE>")
  set(CMAKE_CXX_MODULE_MAP_FORMAT "clang")
  set(CMAKE_CXX_MODULE_MAP_FLAG "@<MODULE_MAP_FILE>")
  set(CMAKE_CXX_COMPILE_BMI
    "<CMAKE_CXX_COMPILER> <DEFINES> <INCLUDES> <FLAGS> -clang:-o -clang:<OBJECT> --precompile <SOURCE>")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
  set(CMAKE_CXX_COMPILER_CLANG_SCAN_DEPS "")
endif()

# C++23 Standard Library Modules (import std; / import std.compat;)
if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
  get_filename_component(_CXX_STD_MOD_DIR "${CMAKE_CXX_COMPILER}" DIRECTORY)
  file(REAL_PATH "${_CXX_STD_MOD_DIR}/../../.." _CXX_STD_MOD_DIR)
  set(_CXX_STD_MOD_DIR "${_CXX_STD_MOD_DIR}/modules")
  set(_CXX_STD_MOD_FILE std.ixx)
  set(_CXX_STD_COMPAT_FILE std.compat.ixx)
elseif(CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
  foreach(_INC $ENV{INCLUDE})
    set(_INC_NORM "${_INC}")
    cmake_path(NORMAL_PATH _INC_NORM)
    if(_INC_NORM MATCHES "/MSVC/[^/]+/include$")
      cmake_path(GET _INC_NORM PARENT_PATH _CXX_STD_MOD_DIR)
      set(_CXX_STD_MOD_DIR "${_CXX_STD_MOD_DIR}/modules")
      set(_CXX_STD_MOD_FILE std.ixx)
      set(_CXX_STD_COMPAT_FILE std.compat.ixx)
      break()
    endif()
  endforeach()
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND NOT CMAKE_CXX_SIMULATE_ID)
  get_filename_component(_CP "${CMAKE_CXX_COMPILER}" DIRECTORY)
  file(REAL_PATH "${_CP}/../share/libc++/v1" _LS)
  if(EXISTS "${_LS}/std.cppm")
    set(_CXX_STD_MOD_DIR "${_LS}")
    set(_CXX_STD_MOD_FILE std.cppm)
    set(_CXX_STD_COMPAT_FILE std.compat.cppm)
  endif()
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  execute_process(
    COMMAND ${CMAKE_CXX_COMPILER} -print-file-name=include/c++/bits/std.cc
    OUTPUT_VARIABLE _GCC_STD_PATH
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if(EXISTS "${_GCC_STD_PATH}")
    get_filename_component(_CXX_STD_MOD_DIR "${_GCC_STD_PATH}" DIRECTORY)
    set(_CXX_STD_MOD_FILE std.cc)
    set(_CXX_STD_COMPAT_FILE std.compat.cc)
  endif()
endif()

if(DEFINED _CXX_STD_MOD_DIR AND DEFINED _CXX_STD_MOD_FILE)
  target_sources(${PROJECT_NAME} PRIVATE
    FILE_SET std
	TYPE CXX_MODULES
    BASE_DIRS "${_CXX_STD_MOD_DIR}"
    FILES "${_CXX_STD_MOD_DIR}/${_CXX_STD_MOD_FILE}"
          "${_CXX_STD_MOD_DIR}/${_CXX_STD_COMPAT_FILE}"
  )
endif()