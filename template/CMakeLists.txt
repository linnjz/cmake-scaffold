cmake_minimum_required(VERSION 3.30)

# All include() calls resolve through cmake/. ImportStd.cmake has to run before
# project(): it sets CMAKE_EXPERIMENTAL_CXX_IMPORT_STD, which must be in place
# before the compiler checks of project() run.
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(ImportStd)

# clang-cl with import std is only supported from CMake 4.4 on; older versions
# abort with an explicit error from cmake/ImportStd.cmake (msvc/clang presets
# still work there).
set(CMAKE_C_STANDARD #{C_STANDARD} CACHE STRING "C language standard (presets set the same value)")
set(CMAKE_CXX_STANDARD #{CXX_STANDARD} CACHE STRING "C++ language standard (presets set the same value)")
set(CMAKE_CXX_STANDARD_REQUIRED ON)

project(#{MAIN_PROJECT_NAME}
    VERSION #{PROJECT_VERSION}
    DESCRIPTION "#{PROJECT_DESCRIPTION}"
    HOMEPAGE_URL "#{PROJECT_HOMEPAGE_URL}"
    LANGUAGES #{PROJECT_LANGUAGES}
)

#{TESTING_SETUP}
include(CMakePackageConfigHelpers)
include(GNUInstallDirs)

include(CompilerId)
include(Platform)
include(ShowIncludesPrefix)
include(OutputLayout)
include(TargetUtils)
include(QtSupport)
# protobuf/gRPC code generation for C++/C#/Java/Python (see cmake/ProtoGen.cmake).
# Tools are searched lazily, so this include is free for projects that never
# generate proto code.
include(ProtoGen)

# Third-party libraries and vcpkg management. When benchmarks are enabled,
# BenchmarkSupport includes Vcpkg.cmake from benchmarks/; uncomment it here for
# other vcpkg packages (a second include() is a no-op).
#include(Vcpkg)              # vcpkg packages (see cmake/Vcpkg.cmake)
#include(PrebuiltLibraries)  # pre-built libraries imported by hand (sample in cmake/PrebuiltLibraries.cmake)

# Parallelism is controlled by the build presets' "jobs" field; when invoking
# the build tool by hand, CMAKE_BUILD_PARALLEL_LEVEL (an *environment*
# variable, not a cache entry) changes the default.
