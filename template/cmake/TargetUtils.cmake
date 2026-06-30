# Helper functions for targets that consume pre-built libraries (copying
# runtime DLLs next to the executable, creating IMPORTED targets by hand).

include_guard(GLOBAL)

# Copy the shared libraries matching <lib_base_names> from <release_lib_path>
# (or <debug_lib_path> in Debug builds; omit it to reuse the release directory)
# next to the target binary. Callers pass ${VCPKG_DYNAMIC_BIN_PATH} /
# ${VCPKG_DYNAMIC_DEBUG_BIN_PATH} or their own paths.
#
# The directory is chosen at configure time, which matches the template's
# single-config presets; with a multi-config generator the release directory is
# always used.
function(CopyTargetDependentLibs target_name lib_base_names release_lib_path debug_lib_path)
    if(NOT TARGET ${target_name})
        message(WARNING "Target ${target_name} does not exist, skipping library copy")
        return()
    endif()

    if(NOT debug_lib_path)
        set(debug_lib_path "${release_lib_path}")
    endif()

    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(search_path "${debug_lib_path}")
    else()
        set(search_path "${release_lib_path}")
    endif()

    if(NOT EXISTS "${search_path}")
        message(WARNING "Library search path does not exist: ${search_path}")
        return()
    endif()

    # vcpkg's Windows debug DLLs usually carry a "d" postfix (fmt.dll ->
    # fmtd.dll). Try that name first in Debug builds and fall back to the
    # suffix-less name for packages that keep the release name in both configs.
    set(_debug_dll_postfix "")
    if(WIN32 AND CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(_debug_dll_postfix "d")
    endif()

    foreach(LIB_BASE_NAME ${lib_base_names})
        set(_candidate_names "${LIB_BASE_NAME}")
        if(_debug_dll_postfix)
            list(PREPEND _candidate_names "${LIB_BASE_NAME}${_debug_dll_postfix}")
        endif()

        unset(FOUND_LIBS)
        unset(_tried_patterns)
        foreach(CANDIDATE_NAME IN LISTS _candidate_names)
            # Linux ships versioned .so names (.so, .so.1, .so.1.2.3); Windows and
            # macOS use an exact suffix.
            if(UNIX AND NOT APPLE)
                set(LIB_PATTERN "${CANDIDATE_NAME}${SHARED_LIB_SUFFIX}*")
            else()
                set(LIB_PATTERN "${CANDIDATE_NAME}${SHARED_LIB_SUFFIX}")
            endif()
            list(APPEND _tried_patterns "${search_path}/${LIB_PATTERN}")

            file(GLOB LIB_FILES
                "${search_path}/${LIB_PATTERN}"
                LIST_DIRECTORIES false
            )

            foreach(LIB_FILE ${LIB_FILES})
                if(EXISTS "${LIB_FILE}" AND NOT IS_DIRECTORY "${LIB_FILE}")
                    get_filename_component(FILE_EXT "${LIB_FILE}" LAST_EXT)
                    if(FILE_EXT MATCHES "\\.(dll|so|dylib|lib|a)$" OR
                       (WIN32 AND (NOT FILE_EXT OR FILE_EXT STREQUAL ".dll")))
                        add_custom_command(TARGET ${target_name} POST_BUILD
                            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                                "${LIB_FILE}"
                                $<TARGET_FILE_DIR:${target_name}>
                            COMMENT "Copying ${LIB_FILE} to output directory"
                        )
                        list(APPEND FOUND_LIBS "${LIB_FILE}")
                    endif()
                endif()
            endforeach()

            if(FOUND_LIBS)
                break()
            endif()
        endforeach()

        if(NOT FOUND_LIBS)
            message(WARNING "No shared library files found for patterns: ${_tried_patterns}")
        else()
            message(STATUS "Copied libraries for ${LIB_BASE_NAME}: ${FOUND_LIBS}")
        endif()
    endforeach()
endfunction()

# Create an IMPORTED SHARED target from a library directory that only contains
# a shared library and its import library (no CMake package config).
function(IMPORTED_LIBRARY target_name lib_base_name library_dir)
    if(TARGET ${target_name})
        return()
    endif()

    set(lib_path "${library_dir}/${lib_base_name}${LIB_SUFFIX}")
    set(shared_lib_base "${library_dir}/${lib_base_name}${SHARED_LIB_SUFFIX}")

    # Handle wildcard for versioned .so files (Linux only)
    set(shared_lib_path "${shared_lib_base}")
    if(UNIX AND NOT APPLE)
        file(GLOB versioned_libs "${shared_lib_base}*")
        if(versioned_libs)
            list(SORT versioned_libs COMPARE NATURAL ORDER DESCENDING)
            list(GET versioned_libs 0 shared_lib_path)
        endif()
    endif()

    if(NOT EXISTS "${shared_lib_path}")
        message(WARNING "Shared library not found: ${shared_lib_base}*")
        return()
    endif()

    add_library(${target_name} SHARED IMPORTED)

    if(WIN32)
        set_target_properties(${target_name} PROPERTIES
            IMPORTED_LOCATION "${shared_lib_path}"
            IMPORTED_IMPLIB "${lib_path}"
            IMPORTED_LOCATION_DEBUG "${shared_lib_path}"
            IMPORTED_IMPLIB_DEBUG "${lib_path}"
            IMPORTED_LOCATION_RELEASE "${shared_lib_path}"
            IMPORTED_IMPLIB_RELEASE "${lib_path}"
        )
    else()
        set_target_properties(${target_name} PROPERTIES
            IMPORTED_LOCATION "${shared_lib_path}"
        )
    endif()

    message(STATUS "Found library: ${shared_lib_path}")
endfunction()

# SetTargetRuntimeDependencyPath() was removed with the rewrite: it read the
# undefined VCPKG_BIN_PATH / VCPKG_DEBUG_BIN_PATH (VcpkgConfig defines
# VCPKG_DYNAMIC_*_BIN_PATH) and only affected the Visual Studio debugger
# environment, which the preset-driven Ninja workflow never uses.
