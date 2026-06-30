# Target lifecycle helpers shared by every subproject: creation (including the
# Qt variants), Qt6 finalization and the install layout. Keeping this here lets
# src/CMakeLists.txt stay declarative instead of repeating generator-specific
# branches in every generated project.

include_guard(GLOBAL)

# scaffold_add_project_target(<target>
#     TYPE <EXE|STATIC|SHARED>
#     SOURCES <file>...
# )
#
# SOURCES is required: CMake rejects add_library() without sources, and an
# explicit list makes additions visible in diffs instead of hiding them in a
# FILE(GLOB).
function(scaffold_add_project_target target)
    cmake_parse_arguments(PARSE_ARGV 1 ARG "" "TYPE" "SOURCES")

    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "scaffold_add_project_target(${target}): unknown arguments: ${ARG_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT ARG_TYPE MATCHES "^(EXE|STATIC|SHARED)$")
        message(FATAL_ERROR "scaffold_add_project_target(${target}): TYPE must be EXE, STATIC or SHARED (got '${ARG_TYPE}')")
    endif()
    if(NOT ARG_SOURCES)
        message(FATAL_ERROR "scaffold_add_project_target(${target}): SOURCES is required")
    endif()

    set(_sources ${ARG_SOURCES})

    # Qt5 converts .qrc files into sources before add_library()/add_executable().
    # The convention is one resource file named after the target; a missing file
    # is not an error, unlike the old template which always referenced it.
    if(QT_SUPPORT AND QT_VERSION_MAJOR LESS 6)
        if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${target}.qrc")
            qt5_add_big_resources(_sources "${CMAKE_CURRENT_SOURCE_DIR}/${target}.qrc")
        endif()
    endif()

    if(ARG_TYPE STREQUAL "EXE")
        if(QT_SUPPORT AND QT_VERSION_MAJOR GREATER_EQUAL 6)
            qt_add_executable(${target} MANUAL_FINALIZATION ${_sources})
        else()
            add_executable(${target} ${_sources})
        endif()
    elseif(ARG_TYPE STREQUAL "STATIC")
        add_library(${target} STATIC ${_sources})
    else()
        add_library(${target} SHARED ${_sources})
    endif()

    # Qt6 resources can belong to either an executable or a library; Qt5 already
    # handled them above because its command rewrites the source list.
    if(QT_SUPPORT AND QT_VERSION_MAJOR GREATER_EQUAL 6)
        scaffold_add_qt_resources(${target})
    endif()
endfunction()

# Attach image/script assets found under the subproject directory as Qt6
# resources. An empty result is skipped: qt_add_resources() with no FILES is
# pointless and some Qt versions reject it.
# GLOB is acceptable here (unlike source files): the result feeds embedded
# resources instead of the scanner, and CONFIGURE_DEPENDS keeps new asset
# files flowing in without a manual re-configure.
function(scaffold_add_qt_resources target)
    file(GLOB_RECURSE _resource_files CONFIGURE_DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/*.png"
        "${CMAKE_CURRENT_SOURCE_DIR}/*.jpg"
        "${CMAKE_CURRENT_SOURCE_DIR}/*.jpeg"
        "${CMAKE_CURRENT_SOURCE_DIR}/*.svg"
        "${CMAKE_CURRENT_SOURCE_DIR}/*.ico"
        "${CMAKE_CURRENT_SOURCE_DIR}/*.ttf"
        "${CMAKE_CURRENT_SOURCE_DIR}/*.webp"
        "${CMAKE_CURRENT_SOURCE_DIR}/*.js"
        "${CMAKE_CURRENT_SOURCE_DIR}/*.json"
        "${CMAKE_CURRENT_SOURCE_DIR}/*.html"
    )
    if(NOT _resource_files)
        return()
    endif()

    foreach(_file ${_resource_files})
        file(RELATIVE_PATH _relative "${CMAKE_CURRENT_SOURCE_DIR}" "${_file}")
        list(APPEND _relative_files "${_relative}")
    endforeach()

    qt_add_resources(${target} "${target}"
        RESOURCES PREFIX "/"
        FILES ${_relative_files}
    )
endfunction()

# Qt6 executables created with MANUAL_FINALIZATION must be finalized after all
# sources and properties are set. qt_finalize_executable() is executable-only:
# calling it on a library target (a supported TARGET_TYPE) is invalid, hence the
# property lookup instead of a caller-supplied type.
function(scaffold_finalize_project_target target)
    if(NOT TARGET ${target})
        message(FATAL_ERROR "scaffold_finalize_project_target: target '${target}' does not exist")
    endif()

    if(QT_SUPPORT AND QT_VERSION_MAJOR GREATER_EQUAL 6)
        get_target_property(_type ${target} TYPE)
        if(_type STREQUAL "EXECUTABLE")
            qt_finalize_executable(${target})
        endif()
    endif()

    # CMake disables scanning for targets containing GENERATED sources; mark
    # sources added since scaffold_enable_import_std() (Dependencies,
    # target_sources()) now that the source list is final. CXX_MODULE_STD is
    # only set by the CMake >= 4.4 route, so also check the helper's marker.
    get_target_property(_std_module ${target} CXX_MODULE_STD)
    get_target_property(_import_std_enabled ${target} SCAFFOLD_IMPORT_STD_ENABLED)
    if((_std_module OR _import_std_enabled) AND COMMAND scaffold_mark_sources_for_module_scanning)
        scaffold_mark_sources_for_module_scanning(${target})
    endif()
endfunction()

# Install the target into configuration-prefixed directories so Debug and
# Release installations can coexist. Libraries additionally install their
# headers; executables have no headers to install.
function(scaffold_install_project_target target)
    if(NOT TARGET ${target})
        message(FATAL_ERROR "scaffold_install_project_target: target '${target}' does not exist")
    endif()

    get_target_property(_type ${target} TYPE)
    set(_config_prefix
        "$<$<CONFIG:Debug>:debug/>$<$<CONFIG:RelWithDebInfo>:relwithdebinfo/>")

    install(TARGETS ${target}
        RUNTIME DESTINATION "${_config_prefix}${CMAKE_INSTALL_BINDIR}"
        LIBRARY DESTINATION "${_config_prefix}${CMAKE_INSTALL_LIBDIR}"
        ARCHIVE DESTINATION "${_config_prefix}${CMAKE_INSTALL_LIBDIR}"
    )

    if(NOT _type STREQUAL "EXECUTABLE")
        install(
            DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/"
            DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/${target}"
            FILES_MATCHING
                PATTERN "*.h"
                PATTERN "*.hpp"
                PATTERN "*.ixx"
                PATTERN "*.cppm"
        )
    endif()
endfunction()
