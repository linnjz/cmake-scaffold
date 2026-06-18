# Official documentation link for compiler option settings
# https://learn.microsoft.com/zh-cn/cpp/build/reference/analyze-code-analysis?view=msvc-170
	
# -----------------------------------------------------------------------------
# Compiler-Specific Configuration(General)
# -----------------------------------------------------------------------------
message(STATUS "CXX Compiler ID: ${CMAKE_CXX_COMPILER_ID}")
if(COMPILER_MSVC_LIKE)
    message(STATUS "Set MSVC compiler options")
    # MSVC Runtime Library Configuration
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
    
    # Debug Information Format
    # if(POLICY CMP0141)
    #     cmake_policy(SET CMP0141 NEW)
    #     # Embedded /Z7; ProgramDatabase /Zi; EditAndContinue /ZI
    #     # If you set CMAKE_MSVC_DEBUG_INFORMATION_FORMAT and then
    #     # add the /Zi /ZI options in compile_options, it will be overridden.
    #     # set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "$<IF:$<AND:$<C_COMPILER_ID:MSVC>,$<CXX_COMPILER_ID:MSVC>>,$<$<CONFIG:Debug>:EditAndContinue>,$<$<CONFIG:RelWithDebInfo>:ProgramDatabase>>")
    # endif()

    # https://learn.microsoft.com/zh-cn/cpp/build/cmake-presets-vs?view=msvc-170
    # General Compilation Options
    set(MSVC_COMPILE_GENERAL_OPTIONS
        /std:c++latest        # Greater and equal c++20, will auto enable module support
        # /ifcOutput ${CMAKE_BINARY_DIR}/  # Generate interface definition file
        /utf-8                # character set
        # C strict standard consistency, disable lenient behavior, 
        # to support C20 module import it must be enabled
        /permissive-
        
        # C++20 Modules Support
        # /experimental:module  # Enable module support (if MSVC ver < 16.11)

        /Zc:__cplusplus       # Correctly set the __cplusplus macro
        /Zc:wchar_t           # wchar_t as a primitive type
        /Zc:forScope          # for loop range consistency
        /Zc:inline            # Remove unused functions
        /Zc:preprocessor

        /W4                   # Warning Level 4
        /WX-                  # Treat warnings as errors, "WX" will not compile, due to the way the standard library's internal code is written
        /MP                   # Multiprocessor Compilation
        #/Zp16                  # x64 16-byte alignment
        /Gd                   # __cdecl calling convention

        # Floating point precision is default; in debug mode it is precise, 
        # in release mode it is fast, or you can set "/fp:fast" or "/fp:strict" to keep it consistent.
        /fp:precise           
        /FC                   # Full Path Diagnosis

        # BUG
        # If the settings, we cannot use coroutines and what Microsoft officially 
        # describes may not be consistent.
        # /await:strict         # Enable cooperative routine support, can use "/await", VS 2026 should replace it as "/await:strict"
        
        # Important! /openmp:llvm and /Qpar cannot be enabled at the same time
        # Because they will compete for control of the loop, leading to compilation confusion and potential runtime conflicts
        /openmp:experimental  # /openmp 2.0, /openmp:experimental 2.0 simd, /openmp:llvm 3.0 simd
        /sdl                  # SDL checks
        /EHsc                 # C Exception Handling
        /errorReport:prompt   # Error Reporting Mode
        /diagnostics:column   # Diagnostic Information Format
        /nologo
        /Gm-                  # Disable minimal rebuild
		#/GR-				  # Disable RTTI
		#/EHs-c-              # Disable exceptions
		#/D_HAS_EXCEPTIONS=0
        # https://learn.microsoft.com/zh-cn/cpp/build/reference/arch-x64?view=msvc-170
        /arch:AVX2            # Enable AVX2 instruction set
		#/arch:ARMv7VE
        /wd5103
        /wd4819
        /wd4251
        /bigobj
    )
	
    if(COMPILER_CLANG_CL)
        list(REMOVE_ITEM MSVC_COMPILE_GENERAL_OPTIONS
            /std:c++latest
            /Zc:preprocessor
            /MP
            /Gm-
        )
    endif()
    add_compile_options("$<$<OR:$<CXX_COMPILER_ID:MSVC>,$<CXX_COMPILER_ID:Clang>>:${MSVC_COMPILE_GENERAL_OPTIONS}>")
    add_compile_definitions(
        _UNICODE
        UNICODE
        NOMINMAX
        _CRT_SECURE_NO_WARNINGS
        _SILENCE_ALL_CXX17_DEPRECATION_WARNINGS
    )
else()
    # GCC/Clang Configuration
    find_program(CCACHE_PROGRAM ccache)
    if(CCACHE_PROGRAM)
        message(STATUS "Found ccache program: ${CCACHE_PROGRAM}")
        set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ${CCACHE_PROGRAM})
        set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ${CCACHE_PROGRAM})
    endif()

    # GCC/Clang General Compilation Options (equivalent to MSVC)
    set(GCC_CLANG_COMPILE_GENERAL_OPTIONS
        $<$<COMPILE_LANGUAGE:CXX>:-std=c++${CMAKE_CXX_STANDARD}>
        $<$<COMPILE_LANGUAGE:C>:-std=c${CMAKE_C_STANDARD}>
        # Character set (equivalent to /utf-8)
        -finput-charset=UTF-8
        -fexec-charset=UTF-8
        
        # Position Independent Code (no direct MSVC equivalent; DLLs are PIC by
        # default). Required when the object code may be linked into a shared
        # library (.so) or used by an executable linked with -pie.
        -fPIC
        # Strict standard compliance (equivalent to /permissive-)
        -pedantic#-errors#
        
        # Correct __cplusplus macro (equivalent to /Zc:__cplusplus)
        # Handled by -std=c++20
        
        # Warning levels (equivalent to /W4)
        -Wall
        -Wextra
        -Wshadow 
        -Wconversion 
        -Wformat-security 
        -Wdouble-promotion
        # Strictly follow the C/C++ language standards and issue warnings 
        # for compiler extensions or non-standard usages prohibited by the standards.
        -Wpedantic 
        
        # Treat warnings as errors (equivalent to /WX)
        -Werror
        
        # Alignment (equivalent to /Zp16)
        #-fpack-struct=16
        
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
        
        # AVX2 instruction set (equivalent to /arch:AVX2)
        -mavx2
		-march=native
		-mtune=native
		# ARM
		# -mcpu=native
        -mfma
		# -mllvm -unroll-count=n
		# -mllvm -pragma-unroll-threshold=n
    )
    
    # C++20 Modules Support (equivalent to /experimental:module)
    if(COMPILER_GCC)
        message(STATUS "Set GCC compiler options")
        add_compile_options(
          -fmodules-ts
          # -mpreferred-stack-boundary=4
        )
    elseif(COMPILER_CLANG)
        message(STATUS "Set Clang compiler options")
        add_compile_options(
          -fmodules
          -fbuiltin-module-map
          -fimplicit-module-maps
          -fprebuilt-module-path=${CMAKE_CURRENT_BINARY_DIR}

          # -mstack-alignment=16
        )
    endif()
    
    add_compile_options("$<$<OR:$<CXX_COMPILER_ID:GNU>,$<CXX_COMPILER_ID:Clang>>:${GCC_CLANG_COMPILE_GENERAL_OPTIONS}>")
    
    add_compile_options(
        # -Wno-unused-parameter
        # -Wno-unused-variable
        -Wno-unused-local-typedef
    )

    add_link_options(
        -fopenmp
        #-fpermissive
    )
    # Export all symbols to the dynamic symbol table (equivalent to -Wl,--export-dynamic);
    # needed for plugins/dlopen and complete backtraces.
    # MinGW's g++ driver rejects -rdynamic and ld's --export-dynamic is unsupported
    # for PE+ targets, so use --export-all-symbols instead.
    if(MINGW)
        add_link_options("-Wl,--export-all-symbols")
    else()
        add_link_options(-rdynamic)
    endif()
endif()
if(COMPILER_MSVC_LIKE)
    add_link_options("/STACK:4194304")
elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    add_link_options("-Wl,-z,stack-size=4194304")
endif()

# -----------------------------------------------------------------------------
# Build Type Configuration
# -----------------------------------------------------------------------------

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    message(STATUS "Build Type: Debug")
    add_definitions(-DDEBUG -D_DEBUG)
    
    if(COMPILER_MSVC_LIKE)
        # MSVC Debug compilation options
        add_compile_options(
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Debug>>:/JMC>"    # Just My Code debugging
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Debug>>:/Zi>"     # /ZI /Zi Edit and Continue
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Debug>>:/Od>"     # Disable optimization
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Debug>>:/RTC1>"   # Runtime error checks
        )
        
        # MSVC Debug link options
        add_link_options(
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Debug>>:/DEBUG>"
        )
    else()
        # GCC/Clang Debug compilation options
        # Equivalent to MSVC: /JMC /Zi /Od /RTC1
        add_compile_options(
            -g3                   # Debug information (equivalent to /DEBUG)
            -ggdb                 # GDB-enhanced debug info: DWARF with gdb extensions (superset of -g/-g3)
            -O0                   # Disable optimization (equivalent to /Od)
            -fno-omit-frame-pointer
            -fno-inline           # Disable inlining
            -fno-optimize-sibling-calls
            -fno-eliminate-unused-debug-types
            -fno-common
            #-fno-strict-aliasing
        )
        
        # GCC/Clang Debug link options
        add_link_options(
            -g
        )
    endif()
    
elseif(CMAKE_BUILD_TYPE STREQUAL "Release")
    message(STATUS "Build Type: Release")
    add_definitions(-DNDEBUG)
    
    if(COMPILER_MSVC_LIKE)
        # MSVC Release compilation options
        add_compile_options(
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Release>>:/O2>"    # Maximize speed
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Release>>:/Ob2>"   # Inline any suitable function
            "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/GL>"    # Whole program optimization
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Release>>:/GF>"    # Enable string pool
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Release>>:/GS>"    # Buffer security check
            "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/Qpar>"  # Auto-parallelization
            #https://learn.microsoft.com/zh-cn/cpp/build/reference/qpar-report-auto-parallelizer-reporting-level?view=msvc-170
            "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/Qpar-report:2>"
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Release>>:/Gy>"    # Function-level linking
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Release>>:/Oi>"    # Intrinsic functions
        )
        
        # MSVC Release link options
        add_link_options(
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Release>>:/OPT:REF>"
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Release>>:/LTCG>"  # Link-time code generation
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Release>>:/DEBUG:NONE>"
        )
    else()
        # GCC/Clang Release compilation options
        # Equivalent to MSVC: /O2 /Ob2 /GL /GF /GS /Qpar /Gy /Oi
        add_compile_options(
            -O3                   # Maximum optimization (equivalent to /O2)
            -flto                 # Link-time optimization (equivalent to /GL)
            -fmerge-constants     # String pooling (equivalent to /GF)
            -finline-functions    # Inline functions (equivalent to /Ob2)
            -funroll-loops        # Unroll loops
            -fomit-frame-pointer  # Omit frame pointer
            # -ffast-math           # Fast math operations
            -fno-math-errno
            # -fno-signed-zeros   # IEEE754 distinguish +0.0 and -0.0
            -ffunction-sections   # Function-level linking
        )

        # Equivalent /Qpar
        #if(COMPILER_GCC)
        #     add_compile_options(
        #       -ftree-parallelize-loops=8
        #     )
        #elseif(COMPILER_CLANG)
        #    add_compile_options(
        #        # https://releases.llvm.org/19.1.0/tools/polly/docs/UsingPollyWithClang.html#automatic-vector-code-generation
        #
        #        Using polly auto analysis and generate OpenMP instruction, so don't manually write OpenMP preprocessing directives
        #        -mllvm -polly 
        #        -mllvm -polly-parallel 
        #        -mllvm -polly-vectorizer=stripmine   # auto vectorize
        #        # BACKEND: GNU(default) or LLVM, GNU only support polly-num-threads and polly-scheduling(runtime)
        #        -mllvm -polly-omp-backend=LLVM       
        #        -mllvm -polly-num-threads=8  
        #        # SCHED: static, dynamic, guided, runtime(default)
        #        -mllvm -polly-scheduling=dynamic     
        #        -mllvm -polly-scheduling-chunksize=1
        #    )
        #endif()

        # GCC/Clang Release link options
        # Equivalent to MSVC: /LTCG /DEBUG:NONE
        add_link_options(
            -flto                 # Link-time optimization (equivalent to /LTCG)
            -s                    # Strip symbols (equivalent to /DEBUG:NONE)
            -Wl,--gc-sections     # equivalent to /Gy
        )
    endif()
    
elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    message(STATUS "Build Type: RelWithDebInfo")
    
    if(COMPILER_MSVC_LIKE)
        # MSVC RelWithDebInfo compilation options
        add_compile_options(
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:RelWithDebInfo>>:/O2>" 
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:RelWithDebInfo>>:/Ob1>"
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:RelWithDebInfo>>:/Zi>" 
            "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:RelWithDebInfo>>:/GL>" 
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:RelWithDebInfo>>:/GF>"
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:RelWithDebInfo>>:/GS>" 
            "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:RelWithDebInfo>>:/Qpar>"
            "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:RelWithDebInfo>>:/Qpar-report:2>"
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:RelWithDebInfo>>:/Gy>" 
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:RelWithDebInfo>>:/Oi>" 
        )
        
        # MSVC RelWithDebInfo link options
        add_link_options(
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:RelWithDebInfo>>:/OPT:REF>"
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:RelWithDebInfo>>:/LTCG>"
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:RelWithDebInfo>>:/DEBUG:FULL>"
        )
    else()
        # GCC/Clang RelWithDebInfo compilation options
        # Equivalent to MSVC: /O2 /Ob1 /Zi /GL /GS /Qpar /Gy /Oi
        add_compile_options(
            -O2                   # Optimize for speed (equivalent to /O2)
            -g                    # Debug information (equivalent to /Zi)
            -fno-omit-frame-pointer
            -flto                 # Link-time optimization (equivalent to /GL)
            -funroll-loops
            -fmerge-constants     # String pooling (equivalent to /GF)
            -finline-functions-called-once
            -ffunction-sections   # Function-level linking
        )
        
        # GCC/Clang RelWithDebInfo link options
        # Equivalent to MSVC: /LTCG /DEBUG:FULL
        add_link_options(
            -flto                 # Link-time optimization (equivalent to /LTCG)
            -g                    # Keep debug symbols (equivalent to /DEBUG:FULL)
            -Wl,--gc-sections     # equivalent to /Gy
        )
    endif()
    
else()
    message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
endif()

# -----------------------------------------------------------------------------
# Sanitizers Configuration
# -----------------------------------------------------------------------------
if(USE_SANITIZERS)
    if(COMPILER_CLANG OR COMPILER_GCC)
        add_compile_options(
            -fsanitize=address
            -fsanitize=undefined
            -fno-omit-frame-pointer
        )
        add_link_options(
            -fsanitize=address
            -fsanitize=undefined
        )
        message(STATUS "Sanitizers enabled")
    else()
        message(WARNING "Sanitizers only supported for Clang/GCC")
    endif()
endif()
