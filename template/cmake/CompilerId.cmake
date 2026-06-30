# Compiler identification and the MSVC runtime library choice.
#
# Every downstream file branches on the COMPILER_* flags defined here instead
# of re-testing CMAKE_CXX_COMPILER_ID / CMAKE_*_SIMULATE_ID, so clang-cl
# (COMPILER_ID=Clang with SIMULATE_ID=MSVC) can never fall through a plain
# "MSVC" test by accident.

include_guard(GLOBAL)

if(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
    message(STATUS "Compiler: MSVC")
    set(COMPILER_MSVC TRUE)
    set(COMPILER_MSVC_LIKE TRUE)
elseif(CMAKE_C_COMPILER_ID MATCHES "MSVC")
    message(STATUS "Compiler: MSVC (detected via C)")
    set(COMPILER_MSVC TRUE)
    set(COMPILER_MSVC_LIKE TRUE)
elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    if(CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
        message(STATUS "Compiler: Clang-Cl (MSVC-compatible)")
        set(COMPILER_CLANG_CL TRUE)
        set(COMPILER_MSVC_LIKE TRUE)
    else()
        message(STATUS "Compiler: Clang")
        set(COMPILER_CLANG TRUE)
        set(COMPILER_MSVC_LIKE FALSE)
    endif()
elseif(CMAKE_C_COMPILER_ID MATCHES "Clang")
    if(CMAKE_C_SIMULATE_ID STREQUAL "MSVC")
        message(STATUS "Compiler: Clang-Cl (MSVC-compatible, detected via C)")
        set(COMPILER_CLANG_CL TRUE)
        set(COMPILER_MSVC_LIKE TRUE)
    else()
        message(STATUS "Compiler: Clang (detected via C)")
        set(COMPILER_CLANG TRUE)
        set(COMPILER_MSVC_LIKE FALSE)
    endif()
elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU")
    message(STATUS "Compiler: GCC")
    set(COMPILER_GCC TRUE)
    set(COMPILER_MSVC_LIKE FALSE)
elseif(CMAKE_C_COMPILER_ID MATCHES "GNU")
    message(STATUS "Compiler: GCC (detected via C)")
    set(COMPILER_GCC TRUE)
    set(COMPILER_MSVC_LIKE FALSE)
else()
    message(WARNING "Unknown compiler: CXX=${CMAKE_CXX_COMPILER_ID} C=${CMAKE_C_COMPILER_ID}")
    set(COMPILER_MSVC_LIKE FALSE)
endif()

if(COMPILER_MSVC_LIKE)
    # Single source of truth for the CRT linkage (the presets inject MD/MT).
    # Everything else follows it: the compile flags configured by
    # CompilerOptions.cmake and the vcpkg triplet picked by Vcpkg.cmake.
    set(MSVC_RUNTIME_MODE "MD" CACHE STRING "MSVC runtime library mode: MD (dynamic CRT) or MT (static CRT)")
    set_property(CACHE MSVC_RUNTIME_MODE PROPERTY STRINGS "MD" "MT")

    if(MSVC_RUNTIME_MODE STREQUAL "MT")
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
        message(STATUS "MSVC runtime library: /MT, /MTd")
    elseif(MSVC_RUNTIME_MODE STREQUAL "MD")
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
        message(STATUS "MSVC runtime library: /MD, /MDd")
    else()
        message(WARNING "MSVC_RUNTIME_MODE '${MSVC_RUNTIME_MODE}' is unknown (expected MD or MT); using /MD")
        set(MSVC_RUNTIME_MODE "MD")
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
    endif()
endif()
