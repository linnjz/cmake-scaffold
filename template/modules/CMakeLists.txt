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

# math is just a plain static library and does not import std itself; the std module is
# compiled centrally by the main target (see cmake/ImportStd.cmake). 
# Enabling it again here would cause the same std module to be compiled by two targets.
include(CompilerOptions)
scaffold_configure_target(${PROJECT_NAME})

set(_config_prefix
    "$<$<CONFIG:Debug>:debug/>$<$<CONFIG:RelWithDebInfo>:relwithdebinfo/>")
install(TARGETS math
    RUNTIME DESTINATION "${_config_prefix}${CMAKE_INSTALL_BINDIR}"
    LIBRARY DESTINATION "${_config_prefix}${CMAKE_INSTALL_LIBDIR}"
    ARCHIVE DESTINATION "${_config_prefix}${CMAKE_INSTALL_LIBDIR}"
)
