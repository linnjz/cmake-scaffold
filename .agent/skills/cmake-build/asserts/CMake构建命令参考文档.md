# CMake 项目构建命令参考文档

> 基于 PDFWiz 项目 CMake 架构分析，提炼通用 CMake 构建命令模板，适用于任何 C++ 项目 + cl.exe (MSVC) 编译器的场景。

---

## 一、项目 CMake 目录结构规范

```
ProjectRoot/
├── CMakeLists.txt              # 项目根 CMake（定义项目、导入 cmake 模块、入口）
├── CMakePresets.json            # 预设配置（只读）
├── CMakeUserPresets.json        # 用户预设配置（可修改）
├── cmake/
│   ├── Global.cmake             # 平台/编译器检测、平台后缀
│   ├── Functions.cmake          # 自定义函数（FindVcpkgPackage 等）
│   ├── Dependencies.cmake       # vcpkg 路径、MSVC 运行时、编译器 include 目录
│   ├── ThirdParty.cmake         # 非 vcpkg 第三方库（IMPORTED 方式）
│   ├── CompilerConfigs.cmake    # 全局编译器标志（add_compile_options）
│   └── TargetCompilerConfig.cmake # 按目标设置的编译器标志（target_compile_options）
├── <ProductDir>/                # 子目录名不固定，可以是 src/ Sources/ MyProduct/ 等
│   ├── CMakeLists.txt           # 【通用】子项目 CMake - 添加源文件、编译选项、自定义命令
│   ├── Dependencies.cmake       # 【通用】子项目依赖管理 - 链接三方库、系统库
│   ├── *.cpp / *.h              # 项目特定源文件，名字不固定
│   └── Tests/                   # 测试子目录（可选）
│       └── CMakeLists.txt       # 测试项目 CMake
└── out/
    ├── build/<presetName>/       # CMake 构建树：cache、Ninja、obj、生成文件
    │   └── artifacts/<BuildType>/<arch>/
    │       ├── bin/              # 开发期运行产物
    │       └── lib/              # 开发期链接产物
    └── install/<presetGroup>/    # 清晰安装树：类似 vcpkg installed/<triplet>
        ├── bin/                  # Release runtime
        ├── lib/                  # Release library/import library
        ├── debug/bin/            # Debug runtime
        ├── debug/lib/            # Debug library/import library
        ├── relwithdebinfo/bin/   # RelWithDebInfo runtime
        └── relwithdebinfo/lib/   # RelWithDebInfo library/import library
```

**核心思想**：
- `cmake/` 文件夹存放通用 CMake 模块，所有项目可复用
- 根 `CMakeLists.txt` 串联全部模块并 `add_subdirectory()` 进入产品子目录
- `out/build/<presetName>` 是开发者构建树，允许杂乱；`out/install/<presetGroup>` 是部署/导入库使用的清晰结构
- 产品子目录下的 `CMakeLists.txt` + `Dependencies.cmake` 是**通用模式**：
  - `CMakeLists.txt` → 注册源文件、设置目标级编译选项、custom command、install 规则
  - `Dependencies.cmake` → 管理该子项目的三方库依赖（独立拆分，职责单一）
- 产品子目录名**不固定**：`src/`、`Sources/`、`PDFWiz/`、`MyProduct/` 均可，取决于项目命名习惯

---

## 二、各层 CMake 文件职责与命令对照

### 2.1 根 `CMakeLists.txt` — 项目入口

**职责**：定义项目名/版本/C++标准 → 导入 cmake 模块 → 设置输出目录 → 配置 Qt → 添加子目录

**通用模板**：

```cmake
cmake_minimum_required(VERSION 3.28)
project(MyProject VERSION 1.0.0 DESCRIPTION "..." HOMEPAGE_URL "" LANGUAGES CXX)

# --- C++ 标准 ---
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# --- Qt 自动处理 ---
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# --- 导入 cmake 模块目录 ---
list(APPEND CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake)

# --- 按顺序导入模块 ---
include(cmake/Global.cmake)            # 1. 平台/编译器检测
include(cmake/Functions.cmake)         # 2. 自定义函数
include(cmake/ThirdParty.cmake)        # 3. 第三方 IMPORTED 库
include(cmake/Dependencies.cmake)      # 4. vcpkg 依赖
include(cmake/CompilerConfigs.cmake)   # 5. 全局编译选项

# --- 构建树内的开发期产物目录 ---
set(PROJECT_BUILD_ARTIFACT_DIR "${CMAKE_BINARY_DIR}/artifacts/${CMAKE_BUILD_TYPE}/${PLATFORM_SUFFIX}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BUILD_ARTIFACT_DIR}/bin")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BUILD_ARTIFACT_DIR}/lib")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${PROJECT_BUILD_ARTIFACT_DIR}/lib")

# --- Qt SDK ---
set(QT_SDK_DIR "E:/Qt/6.6.2/msvc2019_64" CACHE PATH "QT SDK DIR")
list(APPEND CMAKE_PREFIX_PATH ${QT_SDK_DIR})
find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Widgets)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Widgets)

# --- 子项目 ---
add_subdirectory(src)
```

### 2.2 `cmake/Global.cmake` — 平台/编译器检测

**职责**：检测操作系统 → 设置后缀名 → 检测编译器类型 → 设置平台后缀

**核心变量产出**：

| 变量 | 含义 | 示例值 |
|------|------|--------|
| `PLATFORM_NAME` | 平台名 | `Windows` / `Linux` / `macOS` |
| `LIB_SUFFIX` | 静态库后缀 | `.lib` / `.a` |
| `SHARED_LIB_SUFFIX` | 动态库后缀 | `.dll` / `.so` / `.dylib` |
| `COMPILER_MSVC` | 是否 MSVC | `TRUE` |
| `COMPILER_MSVC_LIKE` | 是否 MSVC 系列 | `TRUE`（含 clang-cl） |
| `COMPILER_CLANG_CL` | 是否 clang-cl | `TRUE` |
| `COMPILER_GCC` | 是否 GCC | `TRUE` |
| `COMPILER_CLANG` | 是否 Clang | `TRUE` |
| `PLATFORM_SUFFIX` | 架构后缀 | `x64` / `x86` |

**通用模板**：

```cmake
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

if(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
    set(COMPILER_MSVC TRUE)
    set(COMPILER_MSVC_LIKE TRUE)
elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    if(CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
        set(COMPILER_CLANG_CL TRUE)
        set(COMPILER_MSVC_LIKE TRUE)
    else()
        set(COMPILER_CLANG TRUE)
        set(COMPILER_MSVC_LIKE FALSE)
    endif()
elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU")
    set(COMPILER_GCC TRUE)
    set(COMPILER_MSVC_LIKE FALSE)
endif()

if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(PLATFORM_SUFFIX "x64")
else()
    set(PLATFORM_SUFFIX "x86")
endif()
```

### 2.3 `cmake/Dependencies.cmake` — vcpkg 依赖路径

**职责**：配置 MSVC 运行时 → 自动定位 vcpkg 路径 → 设置 vcpkg triplet → 添加 include 目录

**通用模板**：

```cmake
# MSVC 运行时模式选择：/MD(动态) 或 /MT(静态)
if(COMPILER_MSVC_LIKE)
    set(MSVC_RUNTIME_MODE "MD" CACHE STRING "MSVC runtime mode: MD or MT")
    if(MSVC_RUNTIME_MODE STREQUAL "MT")
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    else()
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
    endif()
endif()

# Vcpkg 路径自动检测
if(DEFINED CMAKE_TOOLCHAIN_FILE AND EXISTS "${CMAKE_TOOLCHAIN_FILE}")
    # 从 toolchain 反推 VCPKG_ROOT
elseif(WIN32)
    set(VCPKG_ROOT "E:/Development/vcpkg" CACHE PATH "Vcpkg root directory")
endif()

# Triplet 设置（Windows 示例）
set(VCPKG_STATIC_TRIPLET "x64-windows-static-md")
set(VCPKG_DYNAMIC_TRIPLET "x64-windows")

# 路径变量
set(VCPKG_DYNAMIC_BIN_PATH "${VCPKG_ROOT}/installed/${VCPKG_DYNAMIC_TRIPLET}/bin")
set(VCPKG_DYNAMIC_DEBUG_BIN_PATH "${VCPKG_ROOT}/installed/${VCPKG_DYNAMIC_TRIPLET}/debug/bin")
set(VCPKG_STATIC_LIBRARY_PATH "${VCPKG_ROOT}/installed/${VCPKG_STATIC_TRIPLET}/lib")
```

### 2.4 `cmake/ThirdParty.cmake` — 非 vcpkg 第三方库

**职责**：使用 `add_library(IMPORTED)` 手动导入不在 vcpkg 中的库（如内部库 NexUs）

**通用模板**：

```cmake
include(ExternalProject)

# 自定义 IMPORTED 库
if(NOT TARGET MyLib)
    add_library(MyLib SHARED IMPORTED GLOBAL)
    set_target_properties(MyLib PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "E:/path/to/include"
        IMPORTED_LOCATION_DEBUG     "E:/path/to/bin/debug/MyLib.dll"
        IMPORTED_IMPLIB_DEBUG       "E:/path/to/lib/debug/MyLib.lib"
        IMPORTED_LOCATION_RELEASE   "E:/path/to/bin/release/MyLib.dll"
        IMPORTED_IMPLIB_RELEASE     "E:/path/to/lib/release/MyLib.lib"
    )
endif()
if(NOT TARGET MyLib::MyLib)
    add_library(MyLib::MyLib ALIAS MyLib)
endif()
```

### 2.5 `cmake/CompilerConfigs.cmake` — 全局编译器标志

**职责**：通过 `add_compile_options()` / `add_link_options()` 设置全局编译/链接选项

**核心 MSVC (cl.exe) 选项对照表**：

| CMake 命令 | 对应 cl.exe 参数 | 说明 |
|------------|------------------|------|
| `/std:c++latest` | `cl /std:c++latest` | 最新 C++ 标准 |
| `/utf-8` | `cl /utf-8` | UTF-8 源文件编码 |
| `/permissive-` | `cl /permissive-` | 严格标准一致性 |
| `/Zc:__cplusplus` | `cl /Zc:__cplusplus` | 正确设置 `__cplusplus` |
| `/Zc:preprocessor` | `cl /Zc:preprocessor` | 标准预处理器 |
| `/W4` | `cl /W4` | 警告级别 4 |
| `/MP` | `cl /MP` | 多进程编译 |
| `/fp:precise` | `cl /fp:precise` | 精确浮点 |
| `/openmp:experimental` | `cl /openmp:experimental` | OpenMP 并行 |
| `/arch:AVX2` | `cl /arch:AVX2` | AVX2 指令集 |
| `/EHsc` | `cl /EHsc` | C++ 异常处理 |
| `/bigobj` | `cl /bigobj` | 大目标文件 |
| `/sdl` | `cl /sdl` | 安全检查 |
| `Debug: /Zi /Od /RTC1` | `cl /Zi /Od /RTC1` | 调试信息/无优化/运行时检查 |
| `Release: /O2 /Ob2 /GL` | `cl /O2 /Ob2 /GL` | 最大速度/全程序优化 |
| `Link: /STACK:4194304` | `link /STACK:4194304` | 栈大小 |
| `Link Debug: /DEBUG` | `link /DEBUG` | 调试符号 |
| `Link Release: /LTCG` | `link /LTCG` | 链接时代码生成 |

**通用模板**：

```cmake
if(COMPILER_MSVC_LIKE)
    set(MSVC_COMPILE_OPTIONS
        /std:c++latest /utf-8 /permissive-
        /Zc:__cplusplus /Zc:preprocessor
        /W4 /MP /fp:precise /openmp:experimental
        /arch:AVX2 /EHsc /bigobj /sdl
        /diagnostics:column /nologo
    )
    add_compile_options("$<$<OR:$<CXX_COMPILER_ID:MSVC>,$<CXX_COMPILER_ID:Clang>>:${MSVC_COMPILE_OPTIONS}>")
    add_compile_definitions(_UNICODE UNICODE NOMINMAX _CRT_SECURE_NO_WARNINGS)
    add_link_options("/STACK:4194304")
endif()

# Build-type specific
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    add_compile_options("$<$<CONFIG:Debug>:/Zi /Od /RTC1 /JMC>")
    add_link_options("$<$<CONFIG:Debug>:/DEBUG>")
elseif(CMAKE_BUILD_TYPE STREQUAL "Release")
    add_compile_options("$<$<CONFIG:Release>:/O2 /Ob2 /GL /GF /Gy /Oi>")
    add_link_options("$<$<CONFIG:Release>:/LTCG /DEBUG:NONE>")
endif()
```

### 2.6 子项目 `CMakeLists.txt` — 通用职责（文件名固定）

**路径**：`<ProductDir>/CMakeLists.txt` （如 `src/CMakeLists.txt`、`PDFWiz/CMakeLists.txt`）

**职责**：
1. 注册该子项目的所有源文件
2. 创建目标（可执行文件或库）
3. 设置该目标专属的编译选项（`target_compile_options`）
4. 设置该目标专属的预定义宏（`target_compile_definitions`）
5. 添加资源文件、自定义命令（`add_custom_command`）
6. 设置安装规则（`install()`）
7. `include(Dependencies.cmake)` 加载依赖管理

**通用模板**：

```cmake
# ============================================================
# 文件名固定为 CMakeLists.txt
# 所在目录名不固定：src/ Sources/ PDFWiz/ 均可
# 职责：注册源文件、目标专属编译选项、custom command、install
# ============================================================

# --- 1. 源文件注册 ---
set(PROJECT_SOURCES
    main.cpp
    Foo.cpp
    Bar.cpp
    Foo.h
    Bar.h
)

# --- 2. 创建目标 ---
if(QT_VERSION_MAJOR GREATER_EQUAL 6)
    qt_add_executable(${PROJECT_NAME} MANUAL_FINALIZATION ${PROJECT_SOURCES})
else()
    add_executable(${PROJECT_NAME} ${PROJECT_SOURCES})
endif()

# --- 3. 目标专属编译选项 ---
target_compile_options(${PROJECT_NAME} PRIVATE
    /wd1234   # 禁用特定警告
    /O2       # 覆盖全局优化
)
target_compile_definitions(${PROJECT_NAME} PRIVATE
    MY_CUSTOM_MACRO=1
)

# --- 4. 资源文件（Qt） ---
file(GLOB_RECURSE RES_PATHS *.png *.jpg *.svg *.ico *.ttf *.qrc)
foreach(filepath ${RES_PATHS})
    string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}/" "" filename ${filepath})
    list(APPEND resource_files ${filename})
endforeach()
qt_add_resources(${PROJECT_NAME} "AppResources" PREFIX "/" FILES ${resource_files})

# --- 5. 依赖管理（独立文件，拆分职责） ---
include(Dependencies.cmake)

# --- 6. 目标属性 ---
set_target_properties(${PROJECT_NAME} PROPERTIES
    WIN32_EXECUTABLE ON
    DEBUG_POSTFIX "d"
)

# --- 7. 自定义命令（POST_BUILD） ---
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "$<TARGET_FILE:SomeLib>"
        $<TARGET_FILE_DIR:${PROJECT_NAME}>
    COMMENT "Copying SomeLib to output..."
)

# --- 8. 安装规则 ---
include(GNUInstallDirs)
set(PROJECT_INSTALL_RUNTIME_DIR "${CMAKE_INSTALL_BINDIR}")
set(PROJECT_INSTALL_LIBRARY_DIR "${CMAKE_INSTALL_LIBDIR}")
set(PROJECT_INSTALL_ARCHIVE_DIR "${CMAKE_INSTALL_LIBDIR}")
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(PROJECT_INSTALL_RUNTIME_DIR "debug/${CMAKE_INSTALL_BINDIR}")
    set(PROJECT_INSTALL_LIBRARY_DIR "debug/${CMAKE_INSTALL_LIBDIR}")
    set(PROJECT_INSTALL_ARCHIVE_DIR "debug/${CMAKE_INSTALL_LIBDIR}")
elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    set(PROJECT_INSTALL_RUNTIME_DIR "relwithdebinfo/${CMAKE_INSTALL_BINDIR}")
    set(PROJECT_INSTALL_LIBRARY_DIR "relwithdebinfo/${CMAKE_INSTALL_LIBDIR}")
    set(PROJECT_INSTALL_ARCHIVE_DIR "relwithdebinfo/${CMAKE_INSTALL_LIBDIR}")
endif()

install(TARGETS ${PROJECT_NAME}
    RUNTIME DESTINATION "${PROJECT_INSTALL_RUNTIME_DIR}"
    LIBRARY DESTINATION "${PROJECT_INSTALL_LIBRARY_DIR}"
    ARCHIVE DESTINATION "${PROJECT_INSTALL_ARCHIVE_DIR}"
)

# --- 9. Qt 6 收尾 ---
if(QT_VERSION_MAJOR EQUAL 6)
    qt_finalize_executable(${PROJECT_NAME})
endif()
```

### 2.7 子项目 `Dependencies.cmake` — 通用职责（文件名固定）

**路径**：`<ProductDir>/Dependencies.cmake` （如 `src/Dependencies.cmake`、`PDFWiz/Dependencies.cmake`）

**职责**：
1. 调用 `FindVcpkgPackage` 查找子项目需要的 vcpkg 包
2. 调用 `target_link_libraries` 链接这些包（vcpkg + 系统库 + 自定义 IMPORTED 库）
3. 仅处理**链接和依赖**，不涉及源文件注册或编译选项

> **为什么拆成独立文件？**
> - 当子项目有大量三方依赖时，不污染 `CMakeLists.txt` 的可读性
> - 依赖的增删改只需修改 `Dependencies.cmake`，与源文件/编译选项解耦
> - 如果一个项目有多个子产品（exe + dll + test），各子项目可以独立管理自己的依赖

**通用模板**：

```cmake
# ============================================================
# 文件名固定为 Dependencies.cmake
# 与同目录的 CMakeLists.txt 配对使用
# 职责：管理该子项目的所有三方库依赖（链接 + 拷贝）
# ============================================================

# --- 1. vcpkg 包查找 ---
FindVcpkgPackage(absl    LINKAGE STATIC REQUIRED CONFIG)
FindVcpkgPackage(cryptpp LINKAGE STATIC REQUIRED CONFIG)
FindVcpkgPackage(pugixml LINKAGE STATIC REQUIRED CONFIG)

# --- 2. 链接依赖库 ---
target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt${QT_VERSION_MAJOR}::Widgets
    NexUs::NexUs
    absl::flat_hash_set
    cryptopp::cryptopp
    pugixml::pugixml
)

# --- 3. 系统库（平台相关） ---
if(WIN32)
    target_link_libraries(${PROJECT_NAME} PRIVATE
        rpcrt4 usp10 dwrite
    )
endif()

# --- 4. 自定义预定义宏（库兼容性） ---
target_compile_definitions(${PROJECT_NAME} PRIVATE CRYPTOPP_ENABLE_NAMESPACE_WEAK=1)

# --- 5. 动态库运行时拷贝 ---
CopyTargetDependentLibs(${PROJECT_NAME} "" ${VCPKG_DYNAMIC_BIN_PATH} ${VCPKG_DYNAMIC_DEBUG_BIN_PATH})
```

### 2.8 子项目 `Tests/CMakeLists.txt` — 测试项目

**路径**：`<ProductDir>/Tests/CMakeLists.txt` （如 `src/Tests/CMakeLists.txt`）

```cmake
set(TEST_SOURCES TestMain.cpp TestFoo.cpp)
qt_add_executable(${PROJECT_NAME}Tests ${TEST_SOURCES})
target_link_libraries(${PROJECT_NAME}Tests PRIVATE
    Qt${QT_VERSION_MAJOR}::Test
    Qt${QT_VERSION_MAJOR}::Widgets
    ${PROJECT_NAME}::${PROJECT_NAME}
)
target_include_directories(${PROJECT_NAME}Tests PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)
```

---

## 三、CMake 构建命令大全（cl.exe 场景）

### 3.1 Preset-first 构建流程（当前模板推荐）

cmake-arithmetic 模板生成的工程应优先使用 presets：

- `CMakePresets.json`：共享的 hidden base preset，如 `base`、`non-qt-base`、`qt-base`、`msvc-base`
- `CMakeUserPresets.json`：本机可见 preset，包含 Qt SDK、vcpkg、架构、toolset 等本地设置

先列出 presets：

```powershell
cmake --list-presets all -S .
```

常见命名：

| 模式 | Configure preset | Build preset |
|------|------------------|--------------|
| 非 Qt Debug | `msvc_x64_debug` | `build-msvc_x64_debug` |
| 非 Qt Release | `msvc_x64_release` | `build-msvc_x64_release` |
| 非 Qt RelWithDebInfo | `msvc_x64_relwithdebinfo` | `build-msvc_x64_relwithdebinfo` |
| Qt Debug | `qt_msvc_x64_debug` | `build-qt_msvc_x64_debug` |
| Qt Release | `qt_msvc_x64_release` | `build-qt_msvc_x64_release` |

非 Qt：

```powershell
cmake --preset "msvc_x64_debug"
cmake --build --preset "build-msvc_x64_debug"
```

Qt：

```powershell
cmake --preset "qt_msvc_x64_debug"
cmake --build --preset "build-qt_msvc_x64_debug"
```

如果生成了 test presets：

```powershell
ctest --preset "test-msvc_x64_debug"
```

> 规则：以 `cmake --list-presets all` 输出为准，不要手写猜测 `Qt-Debug`、`Qt-Release` 这类旧名称。

### 3.2 无 presets 时的手工 Configure fallback

只有在没有 `CMakePresets.json` / `CMakeUserPresets.json`，且不是由 `project.toml + generate.py` 生成的工程时，才手工拼 configure 命令。

```powershell
cmake -B out/build/manual-debug -S . `
    -G "Ninja" `
    -DCMAKE_BUILD_TYPE=Debug `
    -DMSVC_RUNTIME_MODE=MD
```

如果确实需要 Qt/vcpkg，也优先把路径写入 `project.toml` 重新生成 `CMakeUserPresets.json`；手工传 `-DCMAKE_PREFIX_PATH`、`-DVCPKG_*` 只作为临时诊断手段。

### 3.3 无 build preset 时的 Build fallback

```powershell
# 构建全部目标
cmake --build out/build/manual-debug

# 指定并行数（4 核）
cmake --build out/build/manual-debug --parallel 4

# 指定目标名称
cmake --build out/build/manual-debug --target <target-name>

# 多配置生成器才使用 --config
cmake --build out/build/vs --config Release

# 使用 Ninja 生成器时指定 verbose
cmake --build out/build/manual-debug --verbose

# 清理后重建
cmake --build out/build/manual-debug --clean-first
```

### 3.4 完整 Debug 构建流程（preset）

```powershell
cmake --list-presets all -S .
cmake --preset "msvc_x64_debug"
cmake --build --preset "build-msvc_x64_debug"
```

### 3.5 完整 Release 构建流程（preset）

```powershell
cmake --list-presets all -S .
cmake --preset "msvc_x64_release"
cmake --build --preset "build-msvc_x64_release"
```

### 3.6 使用 Visual Studio 生成器 fallback（适合 IDE 调试）

```powershell
cmake -B out/build/vs -S . -G "Visual Studio 17 2022" -A x64
cmake --build out/build/vs --config Debug
```

> **注意**：Visual Studio 生成器是**多配置**生成器，不支持 `-DCMAKE_BUILD_TYPE`，构建时用 `--config Debug/Release` 切换。

### 3.7 NMake Makefiles 生成器 fallback（纯命令行，无 Ninja）

```powershell
# 需要先运行 vcvarsall.bat 设置环境
& "D:/VS2022/Enterprise/VC/Auxiliary/Build/vcvarsall.bat" x64

cmake -B out/build/nmake-debug -S . -G "NMake Makefiles" `
    -DCMAKE_BUILD_TYPE=Debug

cmake --build out/build/nmake-debug
```

---

## 四、cl.exe 编译器参数与 CMake 命令对照表

### 4.1 编译选项（Compiler Options）

| cl.exe 参数 | 含义 | CMake 写法 |
|-------------|------|------------|
| `/std:c++latest` | 最新 C++ 标准 | `add_compile_options(/std:c++latest)` / `set(CMAKE_CXX_STANDARD 23)` |
| `/utf-8` | UTF-8 字符集 | `add_compile_options(/utf-8)` |
| `/permissive-` | 严格标准一致性 | `add_compile_options(/permissive-)` |
| `/W4` | 警告级别 4 | `add_compile_options(/W4)` |
| `/WX` | 警告视为错误 | `add_compile_options(/WX)` |
| `/MP` | 多进程编译 | `add_compile_options(/MP)` |
| `/O2` | 最大化速度 | `add_compile_options(/O2)` |
| `/Ob2` | 内联任意函数 | `add_compile_options(/Ob2)` |
| `/GL` | 全程序优化 | `add_compile_options(/GL)`（需配合 `/LTCG`） |
| `/Zi` | 程序数据库（调试） | `add_compile_options(/Zi)` |
| `/Od` | 禁用优化（调试） | `add_compile_options(/Od)` |
| `/RTC1` | 运行时错误检查 | `add_compile_options(/RTC1)` |
| `/JMC` | Just My Code 调试 | `add_compile_options(/JMC)` |
| `/arch:AVX2` | AVX2 指令集 | `add_compile_options(/arch:AVX2)` |
| `/fp:precise` | 精确浮点模型 | `add_compile_options(/fp:precise)` |
| `/EHsc` | C++ 同步异常 | `add_compile_options(/EHsc)` |
| `/openmp:experimental` | OpenMP | `add_compile_options(/openmp:experimental)` |
| `/sdl` | 安全检查 | `add_compile_options(/sdl)` |
| `/bigobj` | 大目标文件 | `add_compile_options(/bigobj)` |
| `/FC` | 完整路径诊断 | `add_compile_options(/FC)` |
| `/Gd` | `__cdecl` 调用约定 | `add_compile_options(/Gd)` |
| `/Gy` | 函数级链接 | `add_compile_options(/Gy)` |
| `/GF` | 字符串池 | `add_compile_options(/GF)` |
| `/Oi` | 内联函数 | `add_compile_options(/Oi)` |
| `/GS` | 缓冲区安全检查 | `add_compile_options(/GS)` |
| `/Qpar` | 自动并行化 | `add_compile_options(/Qpar)` |
| `/Gm-` | 禁用最小重建 | `add_compile_options(/Gm-)` |
| `/nologo` | 隐藏版权信息 | `add_compile_options(/nologo)` |
| `/diagnostics:column` | 列号诊断 | `add_compile_options(/diagnostics:column)` |

### 4.2 链接选项（Linker Options）

| link.exe 参数 | 含义 | CMake 写法 |
|---------------|------|------------|
| `/DEBUG` | 生成调试符号 | `add_link_options(/DEBUG)` |
| `/DEBUG:FULL` | 完整调试符号 | `add_link_options(/DEBUG:FULL)` |
| `/DEBUG:NONE` | 无调试符号 | `add_link_options(/DEBUG:NONE)` |
| `/LTCG` | 链接时代码生成 | `add_link_options(/LTCG)` |
| `/INCREMENTAL` | 增量链接 | `add_link_options(/INCREMENTAL)` |
| `/STACK:4194304` | 栈大小（4MB） | `add_link_options(/STACK:4194304)` |
| `/OPT:REF` | 移除未引用函数 | `add_link_options(/OPT:REF)` |
| `/machine:x64` | 目标架构 | `add_link_options(/machine:x64)` |

### 4.3 MSVC 运行时库

| CMake 变量值 | 对应 cl.exe 参数 | 含义 |
|-------------|------------------|------|
| `MultiThreadedDLL` | `/MD` | 多线程动态 Release |
| `MultiThreadedDebugDLL` | `/MDd` | 多线程动态 Debug |
| `MultiThreaded` | `/MT` | 多线程静态 Release |
| `MultiThreadedDebug` | `/MTd` | 多线程静态 Debug |

```cmake
# 动态运行时（/MD /MDd 默认）
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")

# 静态运行时（/MT /MTd）
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
```

### 4.4 预定义宏

| 宏 | 说明 | 设置方式 |
|----|------|---------|
| `_UNICODE` / `UNICODE` | Unicode 支持 | `add_compile_definitions(_UNICODE UNICODE)` |
| `NOMINMAX` | 禁用 min/max 宏 | `add_compile_definitions(NOMINMAX)` |
| `_CRT_SECURE_NO_WARNINGS` | 禁用安全警告 | `add_compile_definitions(_CRT_SECURE_NO_WARNINGS)` |
| `DEBUG` / `_DEBUG` | Debug 标识 | `add_compile_definitions($<$<CONFIG:Debug>:DEBUG _DEBUG>)` |
| `NDEBUG` | Release 标识 | `add_compile_definitions($<$<CONFIG:Release>:NDEBUG>)` |

---

## 五、CMake 命令速查表

### 5.1 配置阶段命令

```powershell
# 基本配置
cmake -B <build-dir> -S <source-dir> -G <generator> [options...]

# 指定编译器
cmake -B build -S . -DCMAKE_CXX_COMPILER="path/to/cl.exe"

# 指定构建类型（单配置生成器如 Ninja）
cmake -B build -S . -DCMAKE_BUILD_TYPE=Debug

# 指定构建类型（多配置生成器如 VS）
cmake -B build -S . --config Debug

# 使用预设
cmake --preset <preset-name>
```

### 5.2 构建阶段命令

```powershell
# 基本构建
cmake --build <build-dir>

# 指定配置（多配置生成器）
cmake --build <build-dir> --config Release

# 并行
cmake --build <build-dir> --parallel <N>

# 指定目标
cmake --build <build-dir> --target <target-name>

# 详细输出
cmake --build <build-dir> --verbose
```

### 5.3 清理命令

```powershell
cmake --build <build-dir> --target clean    # 清理构建产物
cmake --build <build-dir> --clean-first     # 先 clean 再 build
Remove-Item -LiteralPath <build-dir> -Recurse # 完全删除缓存重新配置
```

### 5.4 安装命令

```powershell
cmake --install "out/build/<configure-preset>"
```

生成工程的 `installDir` 来自 `CMakeUserPresets.json`，默认是
`out/install/<presetGroup>`。例如 `msvc_x64_debug` 安装到
`out/install/msvc_x64/debug/bin` 和 `out/install/msvc_x64/debug/lib`；
`qt_msvc_x64_release` 安装到 `out/install/qt_msvc_x64/bin` 和
`out/install/qt_msvc_x64/lib`。

---

## 六、常见错误与排查

### 6.1 "找不到 vcpkg 包"

```powershell
# 检查 triplet 是否正确
cmake -B build -DVCPKG_TARGET_TRIPLET="x64-windows-static-md"

# 检查 vcpkg 是否已安装该包
vcpkg list
vcpkg install <package>:x64-windows-static-md
```

### 6.2 "找不到 Qt"

```powershell
# 方法 1：检查当前可见 preset
cmake --list-presets all -S .

# 方法 2：确认 CMakeUserPresets.json 的本地 Qt preset 提供 QTDIR/QT_SDK_DIR
# qt-base 从 $env{QTDIR} 进入 CMAKE_PREFIX_PATH

# 方法 3：临时诊断时才手工设置
$env:QTDIR = "E:/Qt/6.6.2/msvc2019_64"
cmake --preset "qt_msvc_x64_debug"
```

### 6.3 "MSVC 运行时库冲突"

```cmake
# 确保所有库使用相同的运行时模式
# 静态库用 /MT（MT/MTd），动态库用 /MD（MD/MDd），不可混用
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
```

### 6.4 LNK2019 / LNK2001 链接错误

```powershell
# 检查 .lib 是否引用正确
# 查看链接的命令行：
cmake --build build --verbose

# Debug 库自动带 "d" 后缀（由 DEBUG_POSTFIX 控制）
set_target_properties(target PROPERTIES DEBUG_POSTFIX "d")
```

---

## 七、最佳实践总结

1. **Out-of-source 构建**：构建目录放在 `Bin/Build/<Config>`，不污染源码目录
2. **模块化 cmake/**：将平台检测、编译器选项、依赖管理、第三方库拆分为独立 `.cmake` 文件，按顺序 include
3. **使用 CMakePresets**：保存 Qt 路径、生成器、架构等固定配置，免去每次敲长命令行
4. **Ninja 生成器**：比 NMake 快数倍，比 VS 生成器更适合 CI/命令行场景
5. **vcpkg + CMAKE_TOOLCHAIN_FILE**：统一管理第三方 C++ 库，避免手动下载
6. **生成器表达式**：`$<CONFIG:Debug>` / `$<CXX_COMPILER_ID:MSVC>` 实现条件编译，避免手动 if-else
7. **DEBUG_POSTFIX**：Debug 构建的 exe/dll 自动加 `d` 后缀，与 Release 区分
8. **CMakeLists.txt + Dependencies.cmake 配对模式**：子项目目录下这两个文件是**通用模式**，前者负责源文件/编译选项/install，后者负责三方库依赖管理——子目录名不固定，但这两个文件职责固定
