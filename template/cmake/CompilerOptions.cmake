# Compiler and linker options for one target.
#
# Official documentation for the MSVC option set:
# https://learn.microsoft.com/en-us/cpp/build/reference/analyze-code-analysis
#
# Call as: scaffold_configure_target(<target>)
#
# Every per-configuration block is expressed with $<CONFIG:...> generator
# expressions and never guarded by if(CMAKE_BUILD_TYPE): under a multi-config
# generator CMAKE_BUILD_TYPE is empty at configure time, so the old outer
# if(CMAKE_BUILD_TYPE STREQUAL ...) branches silently skipped every Debug,
# Release and RelWithDebInfo option.

include_guard(GLOBAL)

function(scaffold_configure_target target)
    if(NOT TARGET ${target})
        message(FATAL_ERROR "scaffold_configure_target: target '${target}' does not exist")
    endif()

    # -------------------------------------------------------------------------
    # Compiler-specific configuration (general)
    # -------------------------------------------------------------------------
    if(COMPILER_MSVC_LIKE)
        message(STATUS "Set MSVC compiler options")

        # Debug information format (CMP0141); /Zi is added per config below.
        # Embedded /Z7; ProgramDatabase /Zi; EditAndContinue /ZI
        # If CMAKE_MSVC_DEBUG_INFORMATION_FORMAT is set, /Zi /ZI in
        # compile_options would be overridden by it.

        set(MSVC_COMPILE_GENERAL_OPTIONS
            /std:c++latest        # C++20 and later, enables modules support
            /utf-8                # source/execution character set UTF-8
            /permissive-          # strict standard conformance
            /Zc:__cplusplus       # correct __cplusplus macro
            /Zc:wchar_t           # wchar_t is a built-in type
            /Zc:forScope          # standard for-loop scope
            /Zc:inline            # drop unreferenced functions
            /Zc:preprocessor      # standards-conforming preprocessor
            /W4                   # warning level 4
            /WX-                  # do not treat warnings as errors
            /MP                   # multi-process compilation
            /Gd                   # __cdecl calling convention
            /fp:precise           # precise floating point model
            /FC                   # full paths in diagnostics
            /openmp:experimental  # /openmp 2.0, /openmp:experimental 2.0 simd, /openmp:llvm 3.0 simd
            /sdl                  # security checks
            /EHsc                 # synchronous C++ exception model
            /errorReport:prompt   # error report mode
            /diagnostics:column   # diagnostics format (column numbers)
            /nologo               # hide banner
            /Gm-                  # disable minimal rebuild
            #/GR-                 # disable RTTI
            #/EHs-c-              # disable exceptions
            #/D_HAS_EXCEPTIONS=0
            /arch:AVX2            # AVX2 instruction set
            #/arch:ARMv7VE
            /wd5103               # suppress specific warnings
            /wd4819
            /wd4251
            /bigobj               # many sections per object file
            # /ifcOutput ${CMAKE_BINARY_DIR}/  # module interface output (opt-in)
            # /await:strict        # coroutines (VS 2026 and later)
        )

        # Options that must reach consumers (PUBLIC / INTERFACE)
        set(PUBLIC_MSVC_COMPILE_OPTIONS
            /std:c++latest
            /utf-8
            /permissive-
            /Zc:__cplusplus
            /Zc:wchar_t
            /Zc:forScope
            /Zc:preprocessor
            /Gd                       # calling convention affects symbol decoration
            /fp:precise               # float behavior affects inline computation
            /EHsc                     # exception model has to match
            /arch:AVX2                # in case headers use AVX2 intrinsics
            /wd5103
        )
        if(COMPILER_CLANG_CL)
            list(REMOVE_ITEM MSVC_COMPILE_GENERAL_OPTIONS
                /std:c++latest
                /Zc:preprocessor
                /MP
                /Gm-
            )
            list(REMOVE_ITEM PUBLIC_MSVC_COMPILE_OPTIONS
                /std:c++latest
                /Zc:preprocessor
            )
        endif()

        # Derive private options by removing the public ones from the full list
        set(PRIVATE_MSVC_COMPILE_OPTIONS ${MSVC_COMPILE_GENERAL_OPTIONS})
        list(REMOVE_ITEM PRIVATE_MSVC_COMPILE_OPTIONS ${PUBLIC_MSVC_COMPILE_OPTIONS})

        # The compiler-id guard on the PUBLIC options keeps MSVC flags from
        # leaking into consumers that are built with another compiler.
        target_compile_options(${target} PUBLIC
            "$<$<CXX_COMPILER_ID:MSVC,Clang>:${PUBLIC_MSVC_COMPILE_OPTIONS}>"
        )
        # PRIVATE options never leave this target and the enclosing branch
        # already fixed the compiler at configure time, so no runtime ID guard.
        target_compile_options(${target} PRIVATE ${PRIVATE_MSVC_COMPILE_OPTIONS})

        target_compile_definitions(${target} PUBLIC
            _UNICODE
            UNICODE
            NOMINMAX
            _CRT_SECURE_NO_WARNINGS
            _SILENCE_ALL_CXX17_DEPRECATION_WARNINGS
        )

        # clang-cl links through lld-link directly (vs_link_exe wrapper), bypassing
        # the driver's runtime setup, so TUs emitting __uint128_t division (e.g.
        # int128 div128, fastmod 64-bit paths) need compiler-rt builtins explicitly.
        # The library is derived from the compiler's own resource dir, never from a
        # machine-specific path; the MSVC-shipped library of the same name lacks __udivti3.
        if(COMPILER_CLANG_CL AND WIN32)
            if(NOT DEFINED CLANG_CL_BUILTINS_LIB)
                execute_process(
                    COMMAND ${CMAKE_CXX_COMPILER} -print-resource-dir
                    OUTPUT_VARIABLE CLANG_RESOURCE_DIR
                    OUTPUT_STRIP_TRAILING_WHITESPACE
                    ERROR_QUIET
                )
                string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _builtins_processor)
                if(_builtins_processor MATCHES "aarch64|arm64")
                    set(_builtins_arch "aarch64")
                else()
                    set(_builtins_arch "x86_64")
                endif()
                unset(_builtins_processor)
                set(CLANG_CL_BUILTINS_LIB
                    "${CLANG_RESOURCE_DIR}/lib/windows/clang_rt.builtins-${_builtins_arch}.lib"
                    CACHE INTERNAL "compiler-rt builtins for clang-cl on Windows")
                unset(_builtins_arch)
            endif()
            if(EXISTS "${CLANG_CL_BUILTINS_LIB}")
                target_link_libraries(${target} PRIVATE "${CLANG_CL_BUILTINS_LIB}")
            else()
                message(WARNING "clang_rt builtins not found at ${CLANG_CL_BUILTINS_LIB}")
            endif()

            # /openmp:experimental emits LLVM OpenMP calls (__kmpc_*, omp_*) but the
            # link goes through lld-link directly, so the OpenMP import library is
            # never added implicitly. Locate libomp relative to the compiler itself.
            if(NOT DEFINED CLANG_CL_OPENMP_LIB)
                get_filename_component(_clang_bin_dir "${CMAKE_CXX_COMPILER}" DIRECTORY)
                if(NOT IS_ABSOLUTE "${_clang_bin_dir}")
                    find_program(_clang_cl_exe NAMES clang-cl.exe REQUIRED)
                    get_filename_component(_clang_bin_dir "${_clang_cl_exe}" DIRECTORY)
                    unset(_clang_cl_exe CACHE)
                endif()
                get_filename_component(_llvm_root "${_clang_bin_dir}" DIRECTORY)
                find_library(CLANG_CL_OPENMP_LIB NAMES libomp libiomp5md
                    HINTS "${_llvm_root}/lib"
                    NO_DEFAULT_PATH)
                unset(_clang_bin_dir)
                unset(_llvm_root)
                if(CLANG_CL_OPENMP_LIB)
                    set(CLANG_CL_OPENMP_LIB "${CLANG_CL_OPENMP_LIB}"
                        CACHE FILEPATH "LLVM OpenMP import library for clang-cl on Windows")
                else()
                    set(CLANG_CL_OPENMP_LIB "CLANG_CL_OPENMP_LIB-NOTFOUND"
                        CACHE FILEPATH "LLVM OpenMP import library for clang-cl on Windows")
                endif()
            endif()
            if(EXISTS "${CLANG_CL_OPENMP_LIB}")
                target_link_libraries(${target} PRIVATE "${CLANG_CL_OPENMP_LIB}")
            else()
                message(WARNING "LLVM OpenMP library not found (${CLANG_CL_OPENMP_LIB})")
            endif()
        endif()
    else()
        # GCC/Clang configuration
        find_program(CCACHE_PROGRAM ccache)
        if(CCACHE_PROGRAM)
            message(STATUS "Found ccache program: ${CCACHE_PROGRAM}")
            set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ${CCACHE_PROGRAM})
            set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ${CCACHE_PROGRAM})
        endif()

        # GCC/Clang general options (equivalent to the MSVC set above)
        set(GCC_CLANG_COMPILE_GENERAL_OPTIONS
            $<$<COMPILE_LANGUAGE:CXX>:-std=c++${CMAKE_CXX_STANDARD}>
            $<$<COMPILE_LANGUAGE:C>:-std=c${CMAKE_C_STANDARD}>
            # Character set (equivalent to /utf-8)
            -finput-charset=UTF-8
            -fexec-charset=UTF-8

            # Strict standard compliance (equivalent to /permissive-)
            -pedantic

            # Warning levels (equivalent to /W4)
            -Wall
            -Wextra
            -Wshadow
            -Wconversion
            -Wformat-security
            -Wdouble-promotion
            -Wpedantic

            # Treat warnings as errors (unlike the MSVC /WX- above)
            -Werror

            # Floating point precision (equivalent to /fp:precise)
            -fno-fast-math
            #-fno-rtti
            #-fno-exceptions

            # OpenMP support (equivalent to /openmp:experimental)
            -fopenmp

            # Security checks (equivalent to /sdl)
            -fstack-protector-strong
            -D_FORTIFY_SOURCE=2

            # Exception handling (equivalent to /EHsc, default in GCC/Clang)
            -fexceptions

            # Diagnostic format (equivalent to /diagnostics:column)
            -fdiagnostics-color=always
            -fdiagnostics-show-option

            # AVX2 instruction set (equivalent to /arch:AVX2); kept as the
            # portable baseline instead of -march=native, which subsumes both
            # flags and makes the build machine-specific / cross-compile broken.
            -mavx2
            # ARM
            # -mcpu=native
            -mfma
            # -mllvm -unroll-count=n
            # -mllvm -pragma-unroll-threshold=n
        )

        # Options that must reach consumers (PUBLIC / INTERFACE)
        set(PUBLIC_GCC_CLANG_COMPILE_OPTIONS
            -finput-charset=UTF-8    # character set
            -fexec-charset=UTF-8
            -pedantic                # strict standard conformance
            -fPIC                    # position independent code; required when a static library is linked into a shared object
            -fno-fast-math           # precise floating point model
            -fexceptions             # exception model has to match
            -mavx2                   # in case headers use AVX2 intrinsics
            -mfma
        )

        # Private options = all options - public options
        set(PRIVATE_GCC_CLANG_COMPILE_OPTIONS ${GCC_CLANG_COMPILE_GENERAL_OPTIONS})
        list(REMOVE_ITEM PRIVATE_GCC_CLANG_COMPILE_OPTIONS ${PUBLIC_GCC_CLANG_COMPILE_OPTIONS})

        set(EXTRA_WARNING_SUPPRESSIONS
            # -Wno-unused-parameter
            # -Wno-unused-variable
            -Wno-unused-local-typedef
        )

        # Module support options (PRIVATE: module interface BMIs do not propagate,
        # every consumer scans on its own)
        if(COMPILER_GCC)
            message(STATUS "Set GCC compiler options")
            set(MODULE_SUPPORT_OPTIONS
                -fmodules-ts
            )
        elseif(COMPILER_CLANG)
            message(STATUS "Set Clang compiler options")
            set(MODULE_SUPPORT_OPTIONS
                -fmodules
                -fbuiltin-module-map
                -fimplicit-module-maps
                -fprebuilt-module-path=${CMAKE_CURRENT_BINARY_DIR}
            )
        endif()

        # AppleClang has its own compiler ID (not "Clang"), so a guard listing
        # only GNU/Clang would drop every option on macOS.
        target_compile_options(${target} PUBLIC
            "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:${PUBLIC_GCC_CLANG_COMPILE_OPTIONS}>"
        )

        target_compile_options(${target} PRIVATE
            ${PRIVATE_GCC_CLANG_COMPILE_OPTIONS}
            ${EXTRA_WARNING_SUPPRESSIONS}
            ${MODULE_SUPPORT_OPTIONS}
        )

        # Export all symbols to the dynamic symbol table (like -Wl,--export-dynamic);
        # needed for dlopen plugins / complete backtraces. MinGW's g++ driver does
        # not understand -rdynamic and the PE+ ld target does not support
        # --export-dynamic, it needs --export-all-symbols instead.
        if(MINGW)
            target_link_options(${target} PRIVATE -Wl,--export-all-symbols)
        else()
            target_link_options(${target} PRIVATE -rdynamic)
        endif()
        target_link_options(${target} PRIVATE -fopenmp)
    endif()

    # Stack size linker options (private); the GCC/Clang else-branch sits below
    # an if(COMPILER_MSVC_LIKE) so no second ID test is needed (an unknown
    # compiler would fail earlier in CompilerId.cmake).
    if(COMPILER_MSVC_LIKE)
        target_link_options(${target} PRIVATE "/STACK:4194304")
    elseif(APPLE)
        target_link_options(${target} PRIVATE "-Wl,-stack_size,0x400000")
    else()
        target_link_options(${target} PRIVATE "-Wl,-z,stack-size=4194304")
    endif()

    # -------------------------------------------------------------------------
    # Build type configuration (per configuration, generator expressions only)
    # -------------------------------------------------------------------------
    if(CMAKE_CONFIGURATION_TYPES)
        message(STATUS "Build type: multi-config (${CMAKE_CONFIGURATION_TYPES})")
    else()
        message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
    endif()

    # Debug
    target_compile_definitions(${target} PRIVATE
        "$<$<CONFIG:Debug>:DEBUG;_DEBUG>"
    )
    if(COMPILER_MSVC_LIKE)
        target_compile_options(${target} PRIVATE
            # Just My Code debugging
            "$<$<CONFIG:Debug>:/JMC>"
            # Edit and Continue
            "$<$<CONFIG:Debug>:/Zi>"
            # Disable optimization
            "$<$<CONFIG:Debug>:/Od>"
            # Runtime error checks
            "$<$<CONFIG:Debug>:/RTC1>"
        )
        target_link_options(${target} PRIVATE
            "$<$<CONFIG:Debug>:/DEBUG>"
        )
    else()
        target_compile_options(${target} PRIVATE
            "$<$<CONFIG:Debug>:-g3>"
            # GDB-flavoured DWARF debug info (-g/-g3 superset)
            "$<$<CONFIG:Debug>:-ggdb>"
            "$<$<CONFIG:Debug>:-O0>"
            "$<$<CONFIG:Debug>:-fno-omit-frame-pointer>"
            "$<$<CONFIG:Debug>:-fno-inline>"
            "$<$<CONFIG:Debug>:-fno-optimize-sibling-calls>"
            "$<$<CONFIG:Debug>:-fno-eliminate-unused-debug-types>"
            "$<$<CONFIG:Debug>:-fno-common>"
            #"$<$<CONFIG:Debug>:-fno-strict-aliasing>"
        )
        target_link_options(${target} PRIVATE
            "$<$<CONFIG:Debug>:-g>"
        )
    endif()

    # Release
    target_compile_definitions(${target} PRIVATE
        "$<$<CONFIG:Release>:NDEBUG;_NDEBUG>"
    )
    if(COMPILER_MSVC_LIKE)
        target_compile_options(${target} PRIVATE
            "$<$<CONFIG:Release>:/O2>"    # maximize speed
            "$<$<CONFIG:Release>:/Ob2>"   # inline any suitable function
            "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/GL>"    # whole program optimization
            "$<$<CONFIG:Release>:/GF>"
            "$<$<CONFIG:Release>:/GS>"    # buffer security check
            "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/Qpar>"  # auto-parallelization
            "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/Qpar-report:2>"
            "$<$<CONFIG:Release>:/Gy>"    # function-level linking
            "$<$<CONFIG:Release>:/Oi>"    # intrinsic functions
        )
        target_link_options(${target} PRIVATE
            "$<$<CONFIG:Release>:/LTCG>"  # link-time code generation
            "$<$<CONFIG:Release>:/DEBUG:NONE>"
        )
    else()
        target_compile_options(${target} PRIVATE
            "$<$<CONFIG:Release>:-O2>"
            "$<$<CONFIG:Release>:-flto>"
            "$<$<CONFIG:Release>:-fmerge-constants>"
            "$<$<CONFIG:Release>:-finline-functions>"
            "$<$<CONFIG:Release>:-funroll-loops>"
            "$<$<CONFIG:Release>:-fomit-frame-pointer>"
            "$<$<CONFIG:Release>:-ffunction-sections>"
            "$<$<CONFIG:Release>:-fno-math-errno>"
        )
        target_link_options(${target} PRIVATE
            "$<$<CONFIG:Release>:-flto>"
            "$<$<CONFIG:Release>:-s>"
            "$<$<CONFIG:Release>:-Wl,--gc-sections>"
        )
    endif()

    # RelWithDebInfo
    if(COMPILER_MSVC_LIKE)
        target_compile_options(${target} PRIVATE
            "$<$<CONFIG:RelWithDebInfo>:/O2>"
            "$<$<CONFIG:RelWithDebInfo>:/Ob1>"
            "$<$<CONFIG:RelWithDebInfo>:/Zi>"
            "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:RelWithDebInfo>>:/GL>"
            "$<$<CONFIG:RelWithDebInfo>:/GF>"
            "$<$<CONFIG:RelWithDebInfo>:/GS>"
            "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:RelWithDebInfo>>:/Qpar>"
            "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:RelWithDebInfo>>:/Qpar-report:2>"
            "$<$<CONFIG:RelWithDebInfo>:/Gy>"
            "$<$<CONFIG:RelWithDebInfo>:/Oi>"
        )
        target_link_options(${target} PRIVATE
            "$<$<CONFIG:RelWithDebInfo>:/LTCG>"
            "$<$<CONFIG:RelWithDebInfo>:/DEBUG:FULL>"
        )
    else()
        target_compile_options(${target} PRIVATE
            "$<$<CONFIG:RelWithDebInfo>:-O2>"
            "$<$<CONFIG:RelWithDebInfo>:-g>"
            "$<$<CONFIG:RelWithDebInfo>:-fno-omit-frame-pointer>"
            "$<$<CONFIG:RelWithDebInfo>:-flto>"
            "$<$<CONFIG:RelWithDebInfo>:-funroll-loops>"
            "$<$<CONFIG:RelWithDebInfo>:-fmerge-constants>"
            "$<$<CONFIG:RelWithDebInfo>:-finline-functions-called-once>"
            "$<$<CONFIG:RelWithDebInfo>:-ffunction-sections>"
        )
        target_link_options(${target} PRIVATE
            "$<$<CONFIG:RelWithDebInfo>:-flto>"
            "$<$<CONFIG:RelWithDebInfo>:-g>"
            "$<$<CONFIG:RelWithDebInfo>:-Wl,--gc-sections>"
        )
    endif()

    # -------------------------------------------------------------------------
    # Sanitizers (clang/gcc only)
    # -------------------------------------------------------------------------
    if(USE_SANITIZERS)
        if(COMPILER_CLANG OR COMPILER_GCC)
            target_compile_options(${target} PRIVATE
                -fsanitize=address
                -fsanitize=undefined
                -fno-omit-frame-pointer
            )
            target_link_options(${target} PRIVATE
                -fsanitize=address
                -fsanitize=undefined
            )
            message(STATUS "Sanitizers enabled")
        else()
            message(WARNING "Sanitizers only supported for Clang/GCC")
        endif()
    endif()

    # -------------------------------------------------------------------------
    # Target properties
    # -------------------------------------------------------------------------
    if(MINGW)
        set_target_properties(${target} PROPERTIES PREFIX "")
    endif()
    if(COMPILER_MSVC_LIKE)
        set_target_properties(${target} PROPERTIES
            DEBUG_POSTFIX "d"
            COMPILE_PDB_NAME ${target}
            COMPILE_PDB_NAME_DEBUG ${target}d
        )
    endif()
endfunction()
