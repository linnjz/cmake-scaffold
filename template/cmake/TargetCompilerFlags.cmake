# Official documentation link for compiler option settings
# https://learn.microsoft.com/zh-cn/cpp/build/reference/analyze-code-analysis?view=msvc-170

# -----------------------------------------------------------------------------
# Compiler-Specific Configuration(General)
# -----------------------------------------------------------------------------
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

    # 所有 MSVC 编译选项（完整列表）
    set(MSVC_COMPILE_GENERAL_OPTIONS
        /std:c++latest        # C++20 及以上，自动启用模块支持
        /utf-8                # 字符集 UTF-8
        /permissive-          # 严格标准一致性，禁用宽松行为
        /Zc:__cplusplus       # 正确设置 __cplusplus 宏
        /Zc:wchar_t           # wchar_t 作为内置类型
        /Zc:forScope          # 标准 for 循环作用域
        /Zc:inline            # 移除未使用的函数
        /Zc:preprocessor      # 标准预处理器行为
        /W4                   # 警告级别 4
        /WX-                  # 不将警告视为错误
        /MP                   # 多进程编译
        /Gd                   # __cdecl 调用约定
        /fp:precise           # 精确浮点模型
        /FC                   # 诊断信息中显示完整路径
        /openmp:experimental  # /openmp 2.0, /openmp:experimental 2.0 simd, /openmp:llvm 3.0 simd
        /sdl                  # 安全检查
        /EHsc                 # C++ 同步异常处理模型
        /errorReport:prompt   # 错误报告模式
        /diagnostics:column   # 诊断信息格式（列号）
        /nologo               # 隐藏版权信息
        /Gm-                  # 禁用最小重建
		#/GR-				  # 禁用RTTI
		#/EHs-c-              # 禁用异常
		#/D_HAS_EXCEPTIONS=0
        /arch:AVX2            # 启用 AVX2 指令集
		#/arch:ARMv7VE
        /wd5103               # 禁用特定警告
        /wd4819
        /wd4251
        /bigobj               # 支持大量段的目标文件
        # /ifcOutput ${CMAKE_BINARY_DIR}/  # 模块接口输出目录（按需启用）
        # /await:strict        # 协程支持（VS 2026 及以后）
    )
	
    # 必须传播给使用者的选项（PUBLIC / INTERFACE）
    set(PUBLIC_MSVC_COMPILE_OPTIONS
        /std:c++latest
        /utf-8
        /permissive-
        /Zc:__cplusplus
        /Zc:wchar_t
        /Zc:forScope
        /Zc:preprocessor
        /Gd                       # 调用约定影响符号修饰
        /fp:precise               # 浮点行为影响内联计算
        /EHsc                     # 异常处理模型必须匹配
        /arch:AVX2                # 若头文件使用 AVX2 intrinsic
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

    # Derive private MSVC options by removing public ones from the full list
    set(PRIVATE_MSVC_COMPILE_OPTIONS ${MSVC_COMPILE_GENERAL_OPTIONS})
    list(REMOVE_ITEM PRIVATE_MSVC_COMPILE_OPTIONS ${PUBLIC_MSVC_COMPILE_OPTIONS})
    
    # Apply public MSVC options to the target
    target_compile_options(${PROJECT_NAME} PUBLIC
        "$<$<CXX_COMPILER_ID:MSVC,Clang>:${PUBLIC_MSVC_COMPILE_OPTIONS}>"
    )

    # Apply private MSVC options to the target
    target_compile_options(${PROJECT_NAME} PRIVATE
        "$<$<CXX_COMPILER_ID:MSVC,Clang>:${PRIVATE_MSVC_COMPILE_OPTIONS}>"
    )

    # Compiler definitions (all private)
    target_compile_definitions(${PROJECT_NAME} PUBLIC
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
        if(NOT DEFINED STDEX_CLANG_BUILTINS_LIB)
            execute_process(
                COMMAND ${CMAKE_CXX_COMPILER} -print-resource-dir
                OUTPUT_VARIABLE CLANG_RESOURCE_DIR
                OUTPUT_STRIP_TRAILING_WHITESPACE
                ERROR_QUIET
            )
            if(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64|aarch64")
                set(_stdex_builtins_arch "aarch64")
            else()
                set(_stdex_builtins_arch "x86_64")
            endif()
            set(STDEX_CLANG_BUILTINS_LIB
                "${CLANG_RESOURCE_DIR}/lib/windows/clang_rt.builtins-${_stdex_builtins_arch}.lib"
                CACHE INTERNAL "compiler-rt builtins for clang-cl on Windows")
            unset(_stdex_builtins_arch)
        endif()
        if(EXISTS "${STDEX_CLANG_BUILTINS_LIB}")
            target_link_libraries(${PROJECT_NAME} PRIVATE "${STDEX_CLANG_BUILTINS_LIB}")
        else()
            message(WARNING "clang_rt builtins not found at ${STDEX_CLANG_BUILTINS_LIB}")
        endif()
        # /openmp:experimental emits LLVM OpenMP calls (__kmpc_*, omp_*) but the
        # link goes through lld-link directly, so the OpenMP import library is
        # never added implicitly. Locate libomp relative to the compiler itself.
        if(NOT DEFINED STDEX_CLANG_OPENMP_LIB)
            get_filename_component(_stdex_clang_bin_dir "${CMAKE_CXX_COMPILER}" DIRECTORY)
            if(NOT IS_ABSOLUTE "${_stdex_clang_bin_dir}")
                find_program(_stdex_clang_cl_exe NAMES clang-cl.exe REQUIRED)
                get_filename_component(_stdex_clang_bin_dir "${_stdex_clang_cl_exe}" DIRECTORY)
                unset(_stdex_clang_cl_exe CACHE)
            endif()
            get_filename_component(_stdex_llvm_root "${_stdex_clang_bin_dir}" DIRECTORY)
            find_library(STDEX_CLANG_OPENMP_LIB NAMES libomp libiomp5md
                HINTS "${_stdex_llvm_root}/lib"
                NO_DEFAULT_PATH)
            unset(_stdex_clang_bin_dir)
            unset(_stdex_llvm_root)
            if(STDEX_CLANG_OPENMP_LIB)
                set(STDEX_CLANG_OPENMP_LIB "${STDEX_CLANG_OPENMP_LIB}"
                    CACHE FILEPATH "LLVM OpenMP import library for clang-cl on Windows")
            else()
                set(STDEX_CLANG_OPENMP_LIB "STDEX_CLANG_OPENMP_LIB-NOTFOUND"
                    CACHE FILEPATH "LLVM OpenMP import library for clang-cl on Windows")
            endif()
        endif()
        if(EXISTS "${STDEX_CLANG_OPENMP_LIB}")
            target_link_libraries(${PROJECT_NAME} PRIVATE "${STDEX_CLANG_OPENMP_LIB}")
        else()
            message(WARNING "LLVM OpenMP library not found (${STDEX_CLANG_OPENMP_LIB})")
        endif()
    endif()
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
        
        # Strict standard compliance (equivalent to /permissive-)
        -pedantic
        
        # Correct __cplusplus macro (equivalent to /Zc:__cplusplus)
        # Handled by -std=c++20
        
        # Warning levels (equivalent to /W4)
        -Wall
        -Wextra
        -Wshadow
        -Wconversion
        -Wformat-security
        -Wdouble-promotion
        -Wpedantic
        
        # Treat warnings as errors (equivalent to /WX- but we enable it)
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

    # 必须传播给使用者的选项（PUBLIC / INTERFACE）
    set(PUBLIC_GCC_CLANG_COMPILE_OPTIONS
        -finput-charset=UTF-8    # 字符集
        -fexec-charset=UTF-8
        -pedantic                # 严格标准一致性
        -fPIC                    # 位置无关代码（MSVC 无对应项，DLL 默认 PIC）；静态库被链接进共享库(.so)时必需
        -fno-fast-math           # 精确浮点模型
        -fexceptions             # 异常处理模型
        -mavx2                   # AVX2 指令集（若头文件使用 intrinsic）
        -mfma
    )

    # 仅内部使用的选项（PRIVATE）= 全部选项 - 公共选项
    set(PRIVATE_GCC_CLANG_COMPILE_OPTIONS ${GCC_CLANG_COMPILE_GENERAL_OPTIONS})
    list(REMOVE_ITEM PRIVATE_GCC_CLANG_COMPILE_OPTIONS ${PUBLIC_GCC_CLANG_COMPILE_OPTIONS})

    set(EXTRA_WARNING_SUPPRESSIONS
        # -Wno-unused-parameter
        # -Wno-unused-variable
        -Wno-unused-local-typedef
    )

    # 模块支持选项（PRIVATE：模块接口的 BMI 不跨目标传播，消费方各自扫描）
    # GCC/Clang Modules Support: 模板自带 modules/math 模块示例，故这些开关是生效的
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

    # Apply GCC/Clang general options (all private)
    target_compile_options(${PROJECT_NAME} PUBLIC
        "$<$<OR:$<CXX_COMPILER_ID:GNU>,$<CXX_COMPILER_ID:Clang>>:${PUBLIC_GCC_CLANG_COMPILE_OPTIONS}>"
    )
    target_compile_options(${PROJECT_NAME} PRIVATE
        "$<$<OR:$<CXX_COMPILER_ID:GNU>,$<CXX_COMPILER_ID:Clang>>:${PRIVATE_GCC_CLANG_COMPILE_OPTIONS}>"
    )

    # Additional warning suppressions (private)
    target_compile_options(${PROJECT_NAME} PRIVATE
        "$<$<OR:$<CXX_COMPILER_ID:GNU>,$<CXX_COMPILER_ID:Clang>>:${PRIVATE_GCC_CLANG_COMPILE_OPTIONS}>"
        "$<$<OR:$<CXX_COMPILER_ID:GNU>,$<CXX_COMPILER_ID:Clang>>:${EXTRA_WARNING_SUPPRESSIONS}>"
        "$<$<OR:$<CXX_COMPILER_ID:GNU>,$<CXX_COMPILER_ID:Clang>>:${MODULE_SUPPORT_OPTIONS}>"
    )

    # 导出全部符号到动态符号表（对应 -Wl,--export-dynamic）；dlopen 插件 / 完整 backtrace 需要
    # MinGW 的 g++ 驱动不识别 -rdynamic，且 ld 的 --export-dynamic 不支持 PE+ 目标，需用 --export-all-symbols
    if(MINGW)
        target_link_options(${PROJECT_NAME} PRIVATE -Wl,--export-all-symbols)
    else()
        target_link_options(${PROJECT_NAME} PRIVATE -rdynamic)
    endif()
    target_link_options(${PROJECT_NAME} PRIVATE -fopenmp)
endif()

# Stack size linker options (private)
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
    target_compile_definitions(${PROJECT_NAME} PRIVATE DEBUG _DEBUG)
    
    if(COMPILER_MSVC_LIKE)
        # MSVC Debug compilation options (private)
        target_compile_options(${PROJECT_NAME} PRIVATE
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Debug>>:/JMC>"    # Just My Code debugging
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Debug>>:/Zi>"     # Edit and Continue
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Debug>>:/Od>"     # Disable optimization
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Debug>>:/RTC1>"   # Runtime error checks
        )
        
        # MSVC Debug link options (private)
        target_link_options(${PROJECT_NAME} PRIVATE
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Debug>>:/DEBUG>"
        )
    else()
        # GCC/Clang Debug compilation options (private)
        target_compile_options(${PROJECT_NAME} PRIVATE
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Debug>>:-g3>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Debug>>:-ggdb>"  # GDB 增强调试信息（DWARF + gdb 扩展，-g/-g3 的超集）
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Debug>>:-O0>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Debug>>:-fno-omit-frame-pointer>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Debug>>:-fno-inline>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Debug>>:-fno-optimize-sibling-calls>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Debug>>:-fno-eliminate-unused-debug-types>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Debug>>:-fno-common>"
            #"$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Debug>>:-fno-strict-aliasing>"
        )
        
        # GCC/Clang Debug link options (private)
        target_link_options(${PROJECT_NAME} PRIVATE
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Debug>>:-g>"
        )
    endif()
    
elseif(CMAKE_BUILD_TYPE STREQUAL "Release")
    message(STATUS "Build Type: Release")
    target_compile_definitions(${PROJECT_NAME} PRIVATE NDEBUG _NDEBUG)
    
    if(COMPILER_MSVC_LIKE)
        # MSVC Release compilation options (private)
        target_compile_options(${PROJECT_NAME} PRIVATE
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Release>>:/O2>"    # Maximize speed
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Release>>:/Ob2>"   # Inline any suitable function
            "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/GL>"    # Whole program optimization
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Release>>:/GF>"
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Release>>:/GS>"    # Buffer security check
            "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/Qpar>"  # Auto-parallelization
            "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/Qpar-report:2>"
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Release>>:/Gy>"    # Function-level linking
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Release>>:/Oi>"    # Intrinsic functions
        )
        
        # MSVC Release link options (private)
        target_link_options(${PROJECT_NAME} PRIVATE
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Release>>:/LTCG>"  # Link-time code generation
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:Release>>:/DEBUG:NONE>"
        )
    else()
        # GCC/Clang Release compilation options (private)
        target_compile_options(${PROJECT_NAME} PRIVATE
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Release>>:-O3>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Release>>:-flto>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Release>>:-fmerge-constants>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Release>>:-finline-functions>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Release>>:-funroll-loops>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Release>>:-fomit-frame-pointer>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Release>>:-ffunction-sections>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Release>>:-fno-math-errno>"
        )
        
        # GCC/Clang Release link options (private)
        target_link_options(${PROJECT_NAME} PRIVATE
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Release>>:-flto>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Release>>:-s>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:Release>>:-Wl,--gc-sections>"
        )
    endif()
    
elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    message(STATUS "Build Type: RelWithDebInfo")
    # No specific definitions added in original for RelWithDebInfo
    
    if(COMPILER_MSVC_LIKE)
        # MSVC RelWithDebInfo compilation options (private)
        target_compile_options(${PROJECT_NAME} PRIVATE
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
        
        # MSVC RelWithDebInfo link options (private)
        target_link_options(${PROJECT_NAME} PRIVATE
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:RelWithDebInfo>>:/LTCG>"
            "$<$<AND:$<CXX_COMPILER_ID:MSVC,Clang>,$<CONFIG:RelWithDebInfo>>:/DEBUG:FULL>"
        )
    else()
        # GCC/Clang RelWithDebInfo compilation options (private)
        target_compile_options(${PROJECT_NAME} PRIVATE
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:RelWithDebInfo>>:-O2>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:RelWithDebInfo>>:-g>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:RelWithDebInfo>>:-fno-omit-frame-pointer>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:RelWithDebInfo>>:-flto>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:RelWithDebInfo>>:-funroll-loops>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:RelWithDebInfo>>:-fmerge-constants>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:RelWithDebInfo>>:-finline-functions-called-once>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:RelWithDebInfo>>:-ffunction-sections>"
        )
        
        # GCC/Clang RelWithDebInfo link options (private)
        target_link_options(${PROJECT_NAME} PRIVATE
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:RelWithDebInfo>>:-flto>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:RelWithDebInfo>>:-g>"
            "$<$<AND:$<CXX_COMPILER_ID:GNU,Clang>,$<CONFIG:RelWithDebInfo>>:-Wl,--gc-sections>"
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
        target_compile_options(${PROJECT_NAME} PRIVATE
            "$<$<OR:$<CXX_COMPILER_ID:GNU>,$<CXX_COMPILER_ID:Clang>>:-fsanitize=address>"
            "$<$<OR:$<CXX_COMPILER_ID:GNU>,$<CXX_COMPILER_ID:Clang>>:-fsanitize=undefined>"
            "$<$<OR:$<CXX_COMPILER_ID:GNU>,$<CXX_COMPILER_ID:Clang>>:-fno-omit-frame-pointer>"
        )
        target_link_options(${PROJECT_NAME} PRIVATE
            "$<$<OR:$<CXX_COMPILER_ID:GNU>,$<CXX_COMPILER_ID:Clang>>:-fsanitize=address>"
            "$<$<OR:$<CXX_COMPILER_ID:GNU>,$<CXX_COMPILER_ID:Clang>>:-fsanitize=undefined>"
        )
        message(STATUS "Sanitizers enabled")
    else()
        message(WARNING "Sanitizers only supported for Clang/GCC")
    endif()
endif()


if (MINGW)
    set_target_properties(${PROJECT_NAME} PROPERTIES PREFIX "")
endif ()
if (COMPILER_MSVC_LIKE)
    set_target_properties(${PROJECT_NAME} PROPERTIES
        DEBUG_POSTFIX "d"
        COMPILE_PDB_NAME ${PROJECT_NAME}
        COMPILE_PDB_NAME_DEBUG ${PROJECT_NAME}d
    )
endif()