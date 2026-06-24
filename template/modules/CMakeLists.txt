cmake_minimum_required(VERSION 3.30)

project(math
    VERSION 1.0.0
    LANGUAGES CXX
)

add_library(math STATIC)

target_sources(math PRIVATE
    math.cpp
)

target_sources(math PRIVATE
    FILE_SET CXX_MODULES
    BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}"
    FILES "math.cppm"
)

# math 只是普通静态库，自身不 import std；std 模块由主目标统一编译（见 cmake/CxxModules.cmake），
# 这里再 include 一次会让同一个 std 模块被两个目标编译。
include(../cmake/TargetCompilerFlags.cmake)

install(TARGETS math
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
)
