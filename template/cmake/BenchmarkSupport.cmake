# Google Benchmark helpers for the generated benchmarks/ directory.
#
# benchmarks/CMakeLists.txt is only added to the build when project.toml sets
# benchmark_enabled = true. Google Benchmark is expected to come from vcpkg:
# scaffold_find_vcpkg_benchmark() probes the installed packages and the caller
# skips the directory with a WARNING when vcpkg or the benchmark port is
# missing, so a checkout without vcpkg still configures and builds everything
# else. Static vcpkg triplets are preferred when MSVC_RUNTIME_MODE is MT (the
# dynamic triplet links /MD and would mismatch the project CRT).

include_guard(GLOBAL)

include(TargetUtils)

# When the root CMakeLists.txt does not include Vcpkg (manual use of this
# module), include it here. include_guard(GLOBAL) makes this a no-op when the
# generated root already did it.
if(NOT COMMAND FindVcpkgPackage)
    include(Vcpkg)
endif()

# scaffold_find_vcpkg_benchmark(<out-var>)
#
# Looks for the benchmark::benchmark and benchmark::benchmark_main imported
# targets in the vcpkg dynamic/static triplet trees and writes TRUE/FALSE to
# <out-var>. On success SCAFFOLD_BENCHMARK_VCPKG_LINKAGE is set in the caller
# scope (DYNAMIC or STATIC) so scaffold_add_benchmark() knows whether runtime
# DLL copying is required.
function(scaffold_find_vcpkg_benchmark out_found)
    set(${out_found} FALSE PARENT_SCOPE)

    if(NOT COMMAND FindVcpkgPackage)
        return()
    endif()
    if(NOT VCPKG_ROOT)
        return()
    endif()

    if(MSVC_RUNTIME_MODE STREQUAL "MT")
        # No dynamic fallback: x64-windows links /MD, which must not be mixed
        # into an /MT project. Without benchmark in the static (/MT) triplet the
        # caller warns and skips benchmarks instead.
        set(_candidates STATIC)
    else()
        # Both the dynamic triplet and the *-static-md triplet use /MD, so the
        # fallback is CRT-compatible.
        set(_candidates DYNAMIC STATIC)
    endif()

    foreach(_linkage IN LISTS _candidates)
        if(_linkage STREQUAL "DYNAMIC")
            set(_tree "${VCPKG_DYNAMIC_PATH}")
        else()
            set(_tree "${VCPKG_STATIC_PATH}")
        endif()
        if(NOT _tree OR NOT EXISTS "${_tree}")
            continue()
        endif()

        FindVcpkgPackage(benchmark LINKAGE ${_linkage} CONFIG QUIET)
        if(TARGET benchmark::benchmark AND TARGET benchmark::benchmark_main)
            set(${out_found} TRUE PARENT_SCOPE)
            set(SCAFFOLD_BENCHMARK_VCPKG_LINKAGE "${_linkage}" PARENT_SCOPE)
            return()
        endif()
    endforeach()
endfunction()

# scaffold_add_benchmark(<target>
#     SOURCES <file>...
#     [LIBS <target-or-library>...]
#     [INCLUDES <dir>...]
# )
#
# Links benchmark::benchmark_main, so the source only registers BENCHMARK(...)
# cases and must not define main().
function(scaffold_add_benchmark target)
    cmake_parse_arguments(PARSE_ARGV 1 ARG "" "" "SOURCES;LIBS;INCLUDES")

    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "scaffold_add_benchmark(${target}): unknown arguments: ${ARG_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT ARG_SOURCES)
        message(FATAL_ERROR "scaffold_add_benchmark(${target}): SOURCES is required")
    endif()
    if(NOT TARGET benchmark::benchmark OR NOT TARGET benchmark::benchmark_main)
        message(FATAL_ERROR
            "scaffold_add_benchmark(${target}): Google Benchmark targets are missing; "
            "call scaffold_find_vcpkg_benchmark() and skip benchmarks/ on failure")
    endif()

    add_executable(${target} ${ARG_SOURCES})

    target_include_directories(${target} PRIVATE
        "$<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}>"
        ${ARG_INCLUDES}
    )

    target_link_libraries(${target} PRIVATE
        benchmark::benchmark
        benchmark::benchmark_main
        ${ARG_LIBS}
    )

    scaffold_configure_target(${target})

    # Dynamic vcpkg benchmark ships benchmark.dll/benchmark_main.dll; Ninja does
    # not add the vcpkg bin directory to PATH, so copy them next to the binary.
    if(WIN32 AND SCAFFOLD_BENCHMARK_VCPKG_LINKAGE STREQUAL "DYNAMIC")
        CopyTargetDependentLibs(${target} "benchmark;benchmark_main"
            "${VCPKG_DYNAMIC_BIN_PATH}" "${VCPKG_DYNAMIC_DEBUG_BIN_PATH}")
    endif()
endfunction()
