# Benchmark entry point. This directory is copied and add_subdirectory()'d
# only when project.toml sets benchmark_enabled = true.
#
# Benchmarks use the vcpkg-provided Google Benchmark port. When VCPKG_ROOT or
# the benchmark package is missing, this directory warns and returns: configure
# succeeds and every other target still builds. Install it with
#     vcpkg install benchmark
# and make VCPKG_ROOT visible to the configure process, or set
# benchmark_enabled = false in project.toml.
#
# cmake/ is already on CMAKE_MODULE_PATH; scaffold_add_benchmark() applies the
# same compiler options as the project targets.
include(CompilerOptions)
include(BenchmarkSupport)

scaffold_find_vcpkg_benchmark(_scaffold_benchmark_found)
if(NOT _scaffold_benchmark_found)
    message(WARNING
        "Skipping benchmarks: vcpkg Google Benchmark (targets benchmark::benchmark "
        "and benchmark::benchmark_main) was not found. Set VCPKG_ROOT and install "
        "the 'benchmark' port, or set benchmark_enabled = false in project.toml. "
        "The rest of the project is unaffected.")
    return()
endif()

scaffold_add_benchmark(scaffold_benchmarks_basic
    SOURCES benchmark_basic.cpp
)
