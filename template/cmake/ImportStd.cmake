# C++23 standard library modules (import std; / import std.compat;).
#
# The root CMakeLists.txt includes this file BEFORE project(): CMake gates the
# import-std support behind CMAKE_EXPERIMENTAL_CXX_IMPORT_STD, and the value
# has to be in place before the compiler checks run. The generator-expression
# UUID changes with every CMake release that touches the experiment, hence the
# version table below.
#
# The helper is opt-in, call it after the target exists:
#   include(ImportStd)                 # root CMakeLists.txt, pre-project
#   scaffold_enable_import_std(<t>)  # after add_executable/add_library
#
# With CMake < 4.4 the helper adds the compiler-shipped std.ixx/std.cppm/std.cc
# through a FILE_SET std; only ONE target in the build may do that, a second one
# would compile the same module again (ODR violations / duplicate BMI). From
# CMake 4.4 on the helper just sets CXX_MODULE_STD and lets CMake provision the
# std module itself.
#
# clang-cl is only supported with CMake >= 4.4: older versions would need the
# manual clang-scan-deps wiring that the old CxxModules.cmake had at include
# time, but this file runs before project() and cannot know the compiler yet,
# so the < 4.4 helper aborts with an explicit error instead of pretending.

include_guard(GLOBAL)

# CMake disables module scanning for a target containing GENERATED sources
# (Qt AUTOMOC's mocs_compilation.cpp, code generators, ...). `import std;` in
# the hand-written sources then fails with C2230/C2039 because they are
# compiled with the unscanned rules too. CMake has no target-level switch, so
# every non-generated source must be marked explicitly. Call this again after
# the final source list is known: sources added after
# scaffold_enable_import_std() would otherwise stay unscanned.
function(scaffold_mark_sources_for_module_scanning target)
    get_target_property(_sources ${target} SOURCES)
    foreach(_source IN LISTS _sources)
        get_source_file_property(_generated ${_source} GENERATED)
        if(NOT _generated)
            set_source_files_properties(${_source} PROPERTIES CXX_SCAN_FOR_MODULES ON)
        endif()
    endforeach()
endfunction()

if(CMAKE_VERSION VERSION_GREATER_EQUAL "4.4.0")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "f35a9ac6-8463-4d38-8eec-5d6008153e7d")
elseif(CMAKE_VERSION VERSION_GREATER_EQUAL "4.3.0")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "451f2fe2-a8a2-47c3-bc32-94786d8fc91b")
elseif(CMAKE_VERSION VERSION_GREATER_EQUAL "4.0.3")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "d0edc3af-4c50-42ea-a356-e2862fe7a444")
elseif(CMAKE_VERSION VERSION_GREATER_EQUAL "4.0.0")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "a9e1cf81-9932-4810-974b-6eccaf14e457")
elseif(CMAKE_VERSION VERSION_GREATER_EQUAL "3.31.8")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "d0edc3af-4c50-42ea-a356-e2862fe7a444")
elseif(CMAKE_VERSION VERSION_GREATER_EQUAL "3.30.0")
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "0e5b6991-d74f-4b3d-a41c-cf096e0b2508")
endif()

function(scaffold_enable_import_std target)
    if(NOT TARGET ${target})
        message(FATAL_ERROR "scaffold_enable_import_std: target '${target}' does not exist")
    endif()

    # The FINALIZE helper needs to re-mark sources added after this call. It
    # cannot rely on CXX_MODULE_STD alone because the pre-4.4 FILE_SET route
    # never sets that property.
    set_property(TARGET ${target} PROPERTY SCAFFOLD_IMPORT_STD_ENABLED TRUE)

    if(CMAKE_VERSION VERSION_GREATER_EQUAL "4.4")
        # CMake >= 4.4 provisions import std; natively: it locates the std module
        # sources shipped with the toolchain on its own (MSVC via the toolset's
        # modules/modules.json), compiles them once into a provider library named
        # "@cmake_cxx_std.lib" and links it into every consumer. Neither FILE_SET
        # std nor scanner setup is needed for that, and both would get in the
        # way here.
        #
        # Beware: on Ninja the provider is passed to `cmake -E vs_link_exe` as a
        # path relative to the build directory. If the library ends up directly
        # in the build directory, that argument is "@cmake_cxx_std.lib", which
        # vs_link_exe mistakes for an MSVC response file and silently drops,
        # making the link fail with LNK2001 on
        # std::_General_precision_tables_2<...>::_Max_P. OutputLayout.cmake
        # redirects libraries into artifacts/<config>/<arch>/lib, so the
        # argument starts with "artifacts" and stays out of response-file
        # syntax. Should a project drop OutputLayout, append
        #     target_link_options(<target> PRIVATE "${CMAKE_BINARY_DIR}/@cmake_cxx_std.lib")
        # to keep the link working.
        set_property(TARGET ${target} PROPERTY CXX_MODULE_STD ON)
        # Re-applied by scaffold_finalize_project_target() once all sources
        # (Dependencies, target_sources()) are known.
        scaffold_mark_sources_for_module_scanning(${target})
        return()
    endif()

    if(COMPILER_CLANG_CL AND CMAKE_VERSION VERSION_LESS "4.4")
        # The manual clang-scan-deps wiring that used to cover this case has to
        # live at include time; before project() the compiler id is unknown, so
        # inside this function such assignments die with the function scope
        # (probe-verified) and CMake < 4.4 would abort during generation anyway.
        message(FATAL_ERROR
            "import std with clang-cl requires CMake >= 4.4 (this is ${CMAKE_VERSION}). "
            "Switch to the msvc or clang presets on older CMake, or comment out the "
            "scaffold_enable_import_std() call in src/CMakeLists.txt.")
    endif()

    # Locate the std module sources shipped with the toolchain: MSVC installs
    # std.ixx next to the compiler, libc++ ships std.cppm, libstdc++ std.cc.
    if(COMPILER_MSVC)
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
    elseif(COMPILER_CLANG)
        get_filename_component(_CP "${CMAKE_CXX_COMPILER}" DIRECTORY)
        set(_CXX_STD_MOD_CANDIDATES "${_CP}/../share/libc++/v1")
        # Distro LLVM (Debian/Ubuntu) installs libc++ under
        # <llvm-prefix>/share/libc++/v1, while /usr/bin/clang++ is a symlink;
        # derive the prefix from the compiler's resource directory as well.
        execute_process(
            COMMAND "${CMAKE_CXX_COMPILER}" -print-resource-dir
            OUTPUT_VARIABLE _CLANG_RESOURCE_DIR
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
        if(_CLANG_RESOURCE_DIR)
            cmake_path(GET _CLANG_RESOURCE_DIR PARENT_PATH _CLANG_PREFIX)
            cmake_path(GET _CLANG_PREFIX PARENT_PATH _CLANG_PREFIX)
            cmake_path(GET _CLANG_PREFIX PARENT_PATH _CLANG_PREFIX)
            list(APPEND _CXX_STD_MOD_CANDIDATES "${_CLANG_PREFIX}/share/libc++/v1")
        endif()
        foreach(_LS IN LISTS _CXX_STD_MOD_CANDIDATES)
            if(EXISTS "${_LS}/std.cppm")
                file(REAL_PATH "${_LS}" _LS)
                set(_CXX_STD_MOD_DIR "${_LS}")
                set(_CXX_STD_MOD_FILE std.cppm)
                set(_CXX_STD_COMPAT_FILE std.compat.cppm)
                break()
            endif()
        endforeach()
        unset(_CXX_STD_MOD_CANDIDATES)
        unset(_CLANG_RESOURCE_DIR)
        unset(_CLANG_PREFIX)
    elseif(COMPILER_GCC)
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

    if(DEFINED _CXX_STD_MOD_DIR AND EXISTS "${_CXX_STD_MOD_DIR}/${_CXX_STD_MOD_FILE}")
        # CMake < 4.4 provisions import std through a FILE_SET, which may only
        # appear on one target per build; two targets would compile the same
        # std module again (duplicate BMI / ODR). CMake >= 4.4 returned above.
        get_property(_fileset_std_targets GLOBAL
            PROPERTY SCAFFOLD_IMPORT_STD_FILESET_TARGETS)
        if(NOT _fileset_std_targets)
            set(_fileset_std_targets "")
        endif()
        list(FIND _fileset_std_targets "${target}" _fileset_std_index)
        if(_fileset_std_index EQUAL -1)
            if(_fileset_std_targets)
                message(FATAL_ERROR
                    "scaffold_enable_import_std: only one target per build may add "
                    "the std FILE_SET on CMake < 4.4 (already on: ${_fileset_std_targets})")
            endif()
            set_property(GLOBAL PROPERTY
                SCAFFOLD_IMPORT_STD_FILESET_TARGETS "${target}")
        endif()

        target_sources(${target} PRIVATE
            FILE_SET std
            TYPE CXX_MODULES
            BASE_DIRS "${_CXX_STD_MOD_DIR}"
            FILES "${_CXX_STD_MOD_DIR}/${_CXX_STD_MOD_FILE}"
                  "${_CXX_STD_MOD_DIR}/${_CXX_STD_COMPAT_FILE}"
        )

        scaffold_mark_sources_for_module_scanning(${target})
    else()
        # Silence here leaves the failure buried in compiler output far away
        # ("unknown Compiled Module Interface" mapper etc.). Name the missing
        # piece per compiler so configure-time output explains the gap; it is
        # only fatal for sources that actually `import std;`.
        # set() with two quoted args would interleave a list separator between
        # them; string(CONCAT) appends verbatim.
        string(CONCAT _import_std_gap
            "import std requested: the toolchain provides no std module source; "
            "sources that do `import std;` will fail at compile time")
        if(COMPILER_MSVC)
            get_filename_component(_msvc_probe "${CMAKE_CXX_COMPILER}" DIRECTORY)
            file(REAL_PATH "${_msvc_probe}/../../.." _msvc_probe)
            string(APPEND _import_std_gap " (std.ixx not found under ${_msvc_probe}/modules)")
            unset(_msvc_probe)
        elseif(CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
            string(APPEND _import_std_gap
                " (no .../MSVC/*/include entry found in $ENV{INCLUDE})")
        elseif(COMPILER_CLANG)
            string(APPEND _import_std_gap
                " (libc++'s std.cppm not found; Clang needs libc++ installed and -stdlib=libc++)")
        elseif(COMPILER_GCC)
            string(APPEND _import_std_gap
                " (GCC ships bits/std.cc only since GCC 15; this is ${CMAKE_CXX_COMPILER_VERSION})")
        endif()
        message(WARNING "${_import_std_gap}")
        unset(_import_std_gap)
    endif()

    unset(_CXX_STD_MOD_DIR)
    unset(_CXX_STD_MOD_FILE)
    unset(_CXX_STD_COMPAT_FILE)
endfunction()
