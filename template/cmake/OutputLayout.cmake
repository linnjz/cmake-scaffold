# Build artifact layout (bin/lib/pdb/... under artifacts/<config>/<arch>).
#
# The paths embed $<CONFIG> instead of ${CMAKE_BUILD_TYPE}: with a single-config
# generator it resolves to the configured build type, and with a multi-config
# generator it produces one directory per configuration. A literal
# ${CMAKE_BUILD_TYPE} is empty under multi-config, which silently collapsed
# every configuration into the same "artifacts//x64/..." directory.

include_guard(GLOBAL)

set(PROJECT_BUILD_ARTIFACT_DIR "${CMAKE_BINARY_DIR}/artifacts/$<CONFIG>/${PLATFORM_SUFFIX}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BUILD_ARTIFACT_DIR}/bin" CACHE PATH "Runtime output directory")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BUILD_ARTIFACT_DIR}/lib" CACHE PATH "Library output directory")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${PROJECT_BUILD_ARTIFACT_DIR}/lib" CACHE PATH "Archive output directory")

# clang-cl emits PDBs just like cl.exe; gating this on COMPILER_MSVC alone
# dropped the debug database into the source of the build tree for clang-cl.
if(COMPILER_MSVC_LIKE)
    set(CMAKE_COMPILE_PDB_OUTPUT_DIRECTORY "${PROJECT_BUILD_ARTIFACT_DIR}/pdb" CACHE PATH "PDB compile output directory")
    set(CMAKE_PDB_OUTPUT_DIRECTORY "${PROJECT_BUILD_ARTIFACT_DIR}/pdb" CACHE PATH "PDB output directory")
endif()
