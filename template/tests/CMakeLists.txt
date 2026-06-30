# Test entry point. This directory is copied and add_subdirectory()'d only
# when project.toml sets test_enabled = true; the root CMakeLists.txt then
# injects include(CTest) + enable_testing().
#
# cmake/ is already on CMAKE_MODULE_PATH, so the helpers need no path prefix.
# Every target gets the same flags as src/ through scaffold_configure_target().
include(CompilerOptions)
include(TestSupport)

scaffold_add_test(scaffold_tests_basic
    SOURCES test_basic.cpp
)

# ---------------------------------------------------------------------------
# Third-party example (vcpkg)
# ---------------------------------------------------------------------------
# The template itself stays dependency-free. To use GoogleTest, uncomment
# include(Vcpkg) in the root CMakeLists.txt once, then:
#
# FindVcpkgPackage(GTest LINKAGE DYNAMIC CONFIG REQUIRED)
# scaffold_add_test(scaffold_tests_gtest
#     SOURCES test_gtest.cpp
#     LIBS GTest::gtest_main
# )
#
# test_gtest.cpp must not define main() (gtest_main provides it). Catch2 works
# the same way: FindVcpkgPackage(Catch2 ...) + LIBS Catch2::Catch2WithMain.
#
# Testing a library sub-project (target_type = "STATIC"/"SHARED"):
# scaffold_add_test(scaffold_tests_library
#     SOURCES test_library.cpp
#     LIBS MyLib
#     INCLUDES "${CMAKE_SOURCE_DIR}/MyLib"
# )
