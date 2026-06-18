# Detect compiler type
if(COMPILER_MSVC_LIKE)
    if(COMPILER_MSVC)
        # ...<version> /bin/Hostx64/x64/cl.exe
        get_filename_component(CL_EXE_PATH "${CMAKE_CXX_COMPILER}" ABSOLUTE)
        get_filename_component(CL_DIR "${CL_EXE_PATH}" DIRECTORY)
        get_filename_component(HOST_DIR "${CL_DIR}" DIRECTORY)
        get_filename_component(BIN_DIR "${HOST_DIR}" DIRECTORY)
        get_filename_component(VC_TOOLS_INSTALL_DIR "${BIN_DIR}" DIRECTORY)

        set(VC_INCLUDE_DIR "${VC_TOOLS_INSTALL_DIR}/include" CACHE PATH "MSVC C++ standard include directory")
        set(VC_MODULES_DIR "${VC_TOOLS_INSTALL_DIR}/modules" CACHE PATH "MSVC C++ modules directory")
        message(STATUS "MSVC C++ include dir: ${VC_INCLUDE_DIR}")
        message(STATUS "MSVC C++ modules dir: ${VC_MODULES_DIR}")

        if(NOT EXISTS "${VC_INCLUDE_DIR}")
            message(WARNING "❌ MSVC C++ include directory NOT found: ${VC_INCLUDE_DIR}")
            message(FATAL_ERROR "MSVC include directory is required, aborting...")
        else()
            include_directories(${VC_INCLUDE_DIR})
            message(STATUS "✔ MSVC C++ include dir: ${VC_INCLUDE_DIR}")
        endif()

        if(NOT EXISTS "${VC_MODULES_DIR}")
            include_directories(${VC_MODULES_DIR})
            message(WARNING "⚠️ MSVC C++ modules directory NOT found: ${VC_MODULES_DIR} (this may be normal for some MSVC versions)")
        else()
            message(STATUS "✔ MSVC C++ modules dir: ${VC_MODULES_DIR}")
        endif()
    else()
        # Clang-cl compiler
        message(STATUS "🔧 Using Clang-cl compiler: ${CMAKE_CXX_COMPILER}")
        set(COMPILER_FAMILY "Clang-cl")
    endif()
elseif(COMPILER_GCC)
    # GCC compiler
    message(STATUS "🔧 Using GCC compiler: ${CMAKE_CXX_COMPILER}")
    set(COMPILER_FAMILY "GCC")
    
    # For GCC, we don't need to set standard include directories explicitly
    # CMake automatically handles this
elseif(COMPILER_CLANG)
    # Clang compiler
    message(STATUS "🔧 Using Clang compiler: ${CMAKE_CXX_COMPILER}")
    set(COMPILER_FAMILY "Clang")
    
    # For Clang, we don't need to set standard include directories explicitly
    # CMake automatically handles this
else()
    # Unknown compiler
    message(WARNING "⚠️ Unknown compiler: ${CMAKE_CXX_COMPILER_ID}")
    set(COMPILER_FAMILY "Unknown")
endif()

# Configure MSVC runtime library mode
# This keeps /MD, /MDd, /MT and /MTd selectable and stable.
if(COMPILER_MSVC_LIKE)
    set(MSVC_RUNTIME_MODE "MD" CACHE STRING "MSVC runtime mode: MD or MT")
    set_property(CACHE MSVC_RUNTIME_MODE PROPERTY STRINGS "MD" "MT")

    if(MSVC_RUNTIME_MODE STREQUAL "MT")
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>" CACHE STRING "" FORCE)
        message(STATUS "🔧 MSVC runtime library mode: /MT, /MTd")
    else()
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL" CACHE STRING "" FORCE)
        message(STATUS "🔧 MSVC runtime library mode: /MD, /MDd")
    endif()
endif()

# Set vcpkg path based on operating system and compiler
#if(DEFINED ENV{VCPKG_ROOT})
#    set(VCPKG_ROOT $ENV{VCPKG_ROOT} CACHE PATH "Vcpkg root directory")
#else()
#set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" CACHE STRING "")
if(DEFINED CMAKE_TOOLCHAIN_FILE AND EXISTS "${CMAKE_TOOLCHAIN_FILE}")
    get_filename_component(_VcpkgBuildsystemsDir "${CMAKE_TOOLCHAIN_FILE}" DIRECTORY)
    get_filename_component(_VcpkgScriptsDir "${_VcpkgBuildsystemsDir}" DIRECTORY)
    get_filename_component(_VcpkgRootFromToolchain "${_VcpkgScriptsDir}" DIRECTORY)
    set(VCPKG_ROOT "${_VcpkgRootFromToolchain}" CACHE PATH "Vcpkg root directory" FORCE)
elseif(DEFINED VCPKG_ROOT AND NOT VCPKG_ROOT STREQUAL "")
    set(VCPKG_ROOT "${VCPKG_ROOT}" CACHE PATH "Vcpkg root directory" FORCE)
elseif(WIN32)
    set(VCPKG_ROOT "E:/Development/vcpkg" CACHE PATH "Vcpkg root directory" FORCE)
elseif(UNIX AND NOT APPLE)
    set(VCPKG_ROOT "$ENV{HOME}/vcpkg" CACHE PATH "Vcpkg root directory" FORCE)
elseif(APPLE)
    set(VCPKG_ROOT "/opt/vcpkg" CACHE PATH "Vcpkg root directory" FORCE)
else()
    set(VCPKG_ROOT "" CACHE PATH "Vcpkg root directory" FORCE)
    message(WARNING "❌ Unknown operating system, vcpkg path not set")
endif()

if(WIN32)
    if(NOT DEFINED VCPKG_STATIC_TRIPLET OR VCPKG_STATIC_TRIPLET STREQUAL "")
        set(VCPKG_STATIC_TRIPLET "x64-windows-static-md" CACHE STRING "Vcpkg static triplet")
    endif()
    if(NOT DEFINED VCPKG_DYNAMIC_TRIPLET OR VCPKG_DYNAMIC_TRIPLET STREQUAL "")
        set(VCPKG_DYNAMIC_TRIPLET "x64-windows" CACHE STRING "Vcpkg dynamic triplet")
    endif()
elseif(UNIX AND NOT APPLE)
    if(NOT DEFINED VCPKG_STATIC_TRIPLET OR VCPKG_STATIC_TRIPLET STREQUAL "")
        set(VCPKG_STATIC_TRIPLET "x64-linux-static" CACHE STRING "Vcpkg static triplet")
    endif()
    if(NOT DEFINED VCPKG_DYNAMIC_TRIPLET OR VCPKG_DYNAMIC_TRIPLET STREQUAL "")
        set(VCPKG_DYNAMIC_TRIPLET "x64-linux" CACHE STRING "Vcpkg dynamic triplet")
    endif()
elseif(APPLE)
    if(NOT DEFINED VCPKG_STATIC_TRIPLET OR VCPKG_STATIC_TRIPLET STREQUAL "")
        set(VCPKG_STATIC_TRIPLET "x64-osx-static" CACHE STRING "Vcpkg static triplet")
    endif()
    if(NOT DEFINED VCPKG_DYNAMIC_TRIPLET OR VCPKG_DYNAMIC_TRIPLET STREQUAL "")
        set(VCPKG_DYNAMIC_TRIPLET "x64-osx" CACHE STRING "Vcpkg dynamic triplet")
    endif()
endif()

set(VCPKG_STATIC_PATH "${VCPKG_ROOT}/installed/${VCPKG_STATIC_TRIPLET}")
set(VCPKG_STATIC_INCLUDE_PATH "${VCPKG_STATIC_PATH}/include")
set(VCPKG_STATIC_LIBRARY_PATH "${VCPKG_STATIC_PATH}/lib")
set(VCPKG_STATIC_DEBUG_LIBRARY_PATH "${VCPKG_STATIC_PATH}/debug/lib")
set(VCPKG_STATIC_CMAKE_PATH "${VCPKG_STATIC_PATH}/share")
set(VCPKG_STATIC_TOOLS_PATH "${VCPKG_STATIC_PATH}/tools")

set(VCPKG_DYNAMIC_PATH "${VCPKG_ROOT}/installed/${VCPKG_DYNAMIC_TRIPLET}")
set(VCPKG_DYNAMIC_BIN_PATH "${VCPKG_DYNAMIC_PATH}/bin")
set(VCPKG_DYNAMIC_DEBUG_BIN_PATH "${VCPKG_DYNAMIC_PATH}/debug/bin")
set(VCPKG_DYNAMIC_INCLUDE_PATH "${VCPKG_DYNAMIC_PATH}/include")
set(VCPKG_DYNAMIC_LIBRARY_PATH "${VCPKG_DYNAMIC_PATH}/lib")
set(VCPKG_DYNAMIC_DEBUG_LIBRARY_PATH "${VCPKG_DYNAMIC_PATH}/debug/lib")
set(VCPKG_DYNAMIC_CMAKE_PATH "${VCPKG_DYNAMIC_PATH}/share")
set(VCPKG_DYNAMIC_TOOLS_PATH "${VCPKG_DYNAMIC_PATH}/tools")

message(STATUS "🔧 Vcpkg root: ${VCPKG_ROOT}")
message(STATUS "🔧 Vcpkg static path: ${VCPKG_STATIC_PATH}")
message(STATUS "🔧 Vcpkg dynamic path: ${VCPKG_DYNAMIC_PATH}")

list(APPEND CMAKE_PREFIX_PATH ${VCPKG_STATIC_PATH} ${VCPKG_DYNAMIC_PATH})

#include_directories(
#    ${VCPKG_STATIC_INCLUDE_PATH}
#)
#include_directories(SYSTEM
#    ${VCPKG_DYNAMIC_INCLUDE_PATH}
#)