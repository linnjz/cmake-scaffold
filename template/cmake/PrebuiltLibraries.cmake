# Sample: import pre-built libraries that are not managed by vcpkg.
#
# Two parts:
#   1. scaffold_add_prebuilt_library() wraps a pre-built library into an
#      IMPORTED GLOBAL target plus a <name>::<name> alias.
#   2. A registration sample driven by THIRD_PARTY_ROOT. Replace those entries
#      with your own libraries, then uncomment include(PrebuiltLibraries) in the
#      root CMakeLists.txt.
#
# Prefer find_package() (when the library ships a Config file) or vcpkg over
# importing by hand; this file is for libraries that offer neither.
#
# RelWithDebInfo and MinSizeRel need no entries: Platform.cmake maps them to
# the Release configuration via CMAKE_MAP_IMPORTED_CONFIG_*.
#
# Expected sample layout (Windows names shown; use .so/.dylib and drop the
# IMPLIB arguments on other platforms):
#   <THIRD_PARTY_ROOT>/ExampleLib/include/example.h
#   <THIRD_PARTY_ROOT>/ExampleLib/bin/ExampleLibd.dll   (+ .lib, Debug)
#   <THIRD_PARTY_ROOT>/ExampleLib/bin/ExampleLib.dll    (+ .lib, Release)
#   <THIRD_PARTY_ROOT>/ExampleStatic/include/example_static.h
#   <THIRD_PARTY_ROOT>/ExampleStatic/lib/ExampleStatic.lib
#
# Windows cannot link a DLL directly, so every configuration that provides a
# SHARED LOCATION must also provide its import library (IMPLIB). A prebuilt SDK
# shipped for a single configuration may provide only DEBUG_* or only RELEASE_*;
# that file is then reused as the generic location for all configurations.

include_guard(GLOBAL)

# scaffold_add_prebuilt_library(<target>
#     [STATIC]
#     INCLUDE_DIR <dir>
#     [DEBUG_LOCATION <file>] [RELEASE_LOCATION <file>]
#     [DEBUG_IMPLIB <file>] [RELEASE_IMPLIB <file>]
#     [INTERFACE_LINK_LIBRARIES <lib>...]
# )
function(scaffold_add_prebuilt_library target)
    if(target MATCHES "::")
        message(FATAL_ERROR "scaffold_add_prebuilt_library: '${target}' must be a plain name; the '${target}::${target}' alias is created automatically")
    endif()
    if(TARGET ${target})
        return()
    endif()

    cmake_parse_arguments(PARSE_ARGV 1 ARG "STATIC"
        "INCLUDE_DIR;DEBUG_LOCATION;RELEASE_LOCATION;DEBUG_IMPLIB;RELEASE_IMPLIB"
        "INTERFACE_LINK_LIBRARIES")

    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "scaffold_add_prebuilt_library(${target}): unknown arguments: ${ARG_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT ARG_INCLUDE_DIR)
        message(FATAL_ERROR "scaffold_add_prebuilt_library(${target}): INCLUDE_DIR is required")
    endif()
    if(NOT IS_DIRECTORY "${ARG_INCLUDE_DIR}")
        message(FATAL_ERROR "scaffold_add_prebuilt_library(${target}): INCLUDE_DIR does not exist: ${ARG_INCLUDE_DIR}")
    endif()
    if(NOT ARG_DEBUG_LOCATION AND NOT ARG_RELEASE_LOCATION)
        message(FATAL_ERROR "scaffold_add_prebuilt_library(${target}): at least one of DEBUG_LOCATION or RELEASE_LOCATION is required")
    endif()

    foreach(_config DEBUG RELEASE)
        if(ARG_${_config}_LOCATION)
            if(NOT EXISTS "${ARG_${_config}_LOCATION}")
                message(FATAL_ERROR "scaffold_add_prebuilt_library(${target}): ${_config}_LOCATION does not exist: ${ARG_${_config}_LOCATION}")
            endif()
            if(NOT ARG_STATIC AND WIN32 AND NOT ARG_${_config}_IMPLIB)
                message(FATAL_ERROR "scaffold_add_prebuilt_library(${target}): ${_config}_IMPLIB is required on Windows for SHARED libraries")
            endif()
            if(ARG_${_config}_IMPLIB AND NOT EXISTS "${ARG_${_config}_IMPLIB}")
                message(FATAL_ERROR "scaffold_add_prebuilt_library(${target}): ${_config}_IMPLIB does not exist: ${ARG_${_config}_IMPLIB}")
            endif()
        elseif(ARG_${_config}_IMPLIB)
            message(FATAL_ERROR "scaffold_add_prebuilt_library(${target}): ${_config}_IMPLIB given without ${_config}_LOCATION")
        endif()
    endforeach()

    if(ARG_STATIC)
        set(_type STATIC)
    else()
        set(_type SHARED)
    endif()

    add_library(${target} ${_type} IMPORTED GLOBAL)
    set_target_properties(${target} PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${ARG_INCLUDE_DIR}")

    foreach(_config DEBUG RELEASE)
        if(ARG_${_config}_LOCATION)
            set_target_properties(${target} PROPERTIES
                IMPORTED_LOCATION_${_config} "${ARG_${_config}_LOCATION}")
        endif()
        if(ARG_${_config}_IMPLIB)
            set_target_properties(${target} PROPERTIES
                IMPORTED_IMPLIB_${_config} "${ARG_${_config}_IMPLIB}")
        endif()
    endforeach()

    # Single-configuration libraries fall back to a generic location so the
    # configurations without their own entry still link.
    if(ARG_DEBUG_LOCATION AND NOT ARG_RELEASE_LOCATION)
        set_target_properties(${target} PROPERTIES
            IMPORTED_LOCATION "${ARG_DEBUG_LOCATION}")
        if(ARG_DEBUG_IMPLIB)
            set_target_properties(${target} PROPERTIES IMPORTED_IMPLIB "${ARG_DEBUG_IMPLIB}")
        endif()
    elseif(ARG_RELEASE_LOCATION AND NOT ARG_DEBUG_LOCATION)
        set_target_properties(${target} PROPERTIES
            IMPORTED_LOCATION "${ARG_RELEASE_LOCATION}")
        if(ARG_RELEASE_IMPLIB)
            set_target_properties(${target} PROPERTIES IMPORTED_IMPLIB "${ARG_RELEASE_IMPLIB}")
        endif()
    endif()

    if(ARG_INTERFACE_LINK_LIBRARIES)
        set_target_properties(${target} PROPERTIES
            INTERFACE_LINK_LIBRARIES "${ARG_INTERFACE_LINK_LIBRARIES}")
    endif()

    add_library(${target}::${target} ALIAS ${target})
endfunction()

# -----------------------------------------------------------------------------
# Sample registration. Set THIRD_PARTY_ROOT (cache or -D) to your prebuilt
# libraries root to enable it; otherwise the helper above is still available.
# -----------------------------------------------------------------------------
set(THIRD_PARTY_ROOT "" CACHE PATH "Root directory of pre-built third-party libraries")

if(THIRD_PARTY_ROOT)
    # Shared library whose Debug binaries carry the 'd' suffix: each
    # configuration needs its own location and import library.
    scaffold_add_prebuilt_library(ExampleLib
        INCLUDE_DIR      "${THIRD_PARTY_ROOT}/ExampleLib/include"
        DEBUG_LOCATION   "${THIRD_PARTY_ROOT}/ExampleLib/bin/ExampleLibd.dll"
        DEBUG_IMPLIB     "${THIRD_PARTY_ROOT}/ExampleLib/bin/ExampleLibd.lib"
        RELEASE_LOCATION "${THIRD_PARTY_ROOT}/ExampleLib/bin/ExampleLib.dll"
        RELEASE_IMPLIB   "${THIRD_PARTY_ROOT}/ExampleLib/bin/ExampleLib.lib"
    )

    # Static library shipped for one configuration only: no IMPLIB, and the
    # release file is reused for Debug through the generic fallback.
    scaffold_add_prebuilt_library(ExampleStatic
        STATIC
        INCLUDE_DIR      "${THIRD_PARTY_ROOT}/ExampleStatic/include"
        RELEASE_LOCATION "${THIRD_PARTY_ROOT}/ExampleStatic/lib/ExampleStatic.lib"
        # INTERFACE_LINK_LIBRARIES ws2_32   # system libraries it depends on
    )
else()
    message(STATUS "PrebuiltLibraries: THIRD_PARTY_ROOT is empty, sample libraries are not imported")
endif()
