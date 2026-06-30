# Platform (OS / architecture) detection and build-type defaults.

include_guard(GLOBAL)

if(WIN32)
    set(PLATFORM_NAME "Windows")
    set(LIB_SUFFIX ".lib")
    set(SHARED_LIB_SUFFIX ".dll")
elseif(APPLE)
    set(PLATFORM_NAME "macOS")
    set(LIB_SUFFIX ".a")
    set(SHARED_LIB_SUFFIX ".dylib")
elseif(UNIX)
    set(PLATFORM_NAME "Linux")
    set(LIB_SUFFIX ".a")
    set(SHARED_LIB_SUFFIX ".so")
endif()

# Architecture detection. CMake regexes are case-sensitive and the Windows
# reports of CMAKE_SYSTEM_PROCESSOR are uppercase ("AMD64", "ARM64"), so the
# value is normalized to lowercase before matching. MSVC-family compilers also
# report the *target* architecture via CMAKE_<LANG>_COMPILER_ARCHITECTURE_ID,
# which wins over the host value because they disagree under cross compiling.
set(_arch_raw "${CMAKE_CXX_COMPILER_ARCHITECTURE_ID}")
if(NOT _arch_raw)
    set(_arch_raw "${CMAKE_SYSTEM_PROCESSOR}")
endif()
string(TOLOWER "${_arch_raw}" _arch_raw)

if(_arch_raw MATCHES "^(amd64|x86_64|x64)$")
    set(_arch "x64")
elseif(_arch_raw MATCHES "^(x86|i[3-6]86)$")
    set(_arch "x86")
elseif(_arch_raw MATCHES "^(aarch64|arm64)$")
    set(_arch "arm64")
elseif(_arch_raw MATCHES "^arm")
    set(_arch "arm")
else()
    message(WARNING "Unknown CPU architecture: ${CMAKE_SYSTEM_PROCESSOR}, falling back to pointer size")
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(_arch "x64")
    else()
        set(_arch "x86")
    endif()
endif()

set(PLATFORM_SUFFIX "${_arch}")
unset(_arch)
unset(_arch_raw)

# Some package exports only provide Debug/Release artifacts.
# Keep RelWithDebInfo and MinSizeRel mapped to Release reliably.
if(NOT CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO)
    set(CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO "Release")
endif()
if(NOT CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL)
    set(CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL "Release")
endif()

# Default build type for single-config generators. Multi-config generators
# (Visual Studio, Ninja Multi-Config) reject an empty-config default and pick
# the configuration per build/install invocation instead. CMAKE_CONFIGURATION_TYPES
# is deliberately not touched: forcing it used to make CMAKE_BUILD_TYPE look
# non-empty, killing this default.
get_property(_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(NOT _multi_config AND NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Choose the type of build")
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "RelWithDebInfo" "MinSizeRel")
endif()
unset(_multi_config)
