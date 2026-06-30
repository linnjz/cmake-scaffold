# CTest helpers for the generated tests/ directory.
#
# tests/CMakeLists.txt is only added to the build when project.toml sets
# test_enabled = true; the root CMakeLists.txt then injects include(CTest) and
# enable_testing(). This file only wires one executable to one CTest entry so
# a new test needs a single call instead of repeating the target boilerplate.

include_guard(GLOBAL)

# scaffold_add_test(<target>
#     SOURCES <file>...
#     [NAME <ctest-name>]
#     [LIBS <target-or-library>...]
#     [INCLUDES <dir>...]
#     [ARGS <arg>...]
#     [WORKING_DIRECTORY <dir>]
# )
#
# The default test name is the target name. ARGS are passed to the executable
# after its path in the CTest command line.
#
# Third-party test frameworks have to be added by the project (see the
# commented vcpkg/GTest recipe in tests/CMakeLists.txt); the generated example
# deliberately stays dependency-free.
function(scaffold_add_test target)
    cmake_parse_arguments(PARSE_ARGV 1 ARG "" "NAME;WORKING_DIRECTORY"
        "SOURCES;LIBS;INCLUDES;ARGS")

    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "scaffold_add_test(${target}): unknown arguments: ${ARG_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT ARG_SOURCES)
        message(FATAL_ERROR "scaffold_add_test(${target}): SOURCES is required")
    endif()
    if(NOT ARG_NAME)
        set(ARG_NAME "${target}")
    endif()

    add_executable(${target} ${ARG_SOURCES})

    # The project root is on the include path so a test can include headers from
    # src/ without repeating the path; extra entries come from INCLUDES.
    target_include_directories(${target} PRIVATE
        "$<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}>"
        ${ARG_INCLUDES}
    )

    if(ARG_LIBS)
        target_link_libraries(${target} PRIVATE ${ARG_LIBS})
    endif()

    scaffold_configure_target(${target})

    add_test(NAME ${ARG_NAME} COMMAND ${target} ${ARG_ARGS})
    if(ARG_WORKING_DIRECTORY)
        set_tests_properties(${ARG_NAME} PROPERTIES
            WORKING_DIRECTORY "${ARG_WORKING_DIRECTORY}")
    endif()
endfunction()
