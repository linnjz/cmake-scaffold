# cmake-scaffold

[English](README.md) | **简体中文**

TOML 驱动的现代 C++ CMake 脚手架。只改一个 `project.toml`，运行 `python generate.py`，就能得到一份可直接构建的工程：MSVC / clang-cl / Clang / GCC 的可移植预设、成体系的编译选项、C++23 标准库模块（`import std;`）、可选的 Qt 与 vcpkg 集成、protobuf/gRPC 代码生成，以及 clang / VS Code 工具配置。

```toml
[project]
name = "MyApp"
```

```powershell
python generate.py
cmake --preset msvc_x64_debug
cmake --build --preset build-msvc_x64_debug
```

`generate.py` 把 `template/` 骨架渲染到 `./<project.name>/`，不会修改仓库里的其它内容。

## 设计要点

- **一个输入，可复现的产物。** 预设、语言标准、编译选项和目标接线都由 `project.toml` 生成，换一台机器不需要再手改 CMake 文件。
- **预设分两层。** `CMakePresets.json`（Public 层）只放可共享的框架设置，不含本机路径；`CMakeUserPresets.json`（User 层）放本机可见的「编译器 × 架构 × 构建类型」预设、`installDir` 等。
- **不烘焙 SDK 路径。** Qt 通过 `QT_SDK_DIR` → `CMAKE_PREFIX_PATH` 查找，vcpkg 通过 toolchain 文件 / `VCPKG_ROOT` 定位，没有任何 `E:/...` 假设。
- **默认现代，扩展按需。** 默认 C++23 + `import std;`；Qt、vcpkg、预编译库、proto 代码生成都是取消一行注释即可启用。

## 快速开始

### 1. 编辑 `project.toml`

最少只需要 `[project] name`。其余表决定生成哪些预设、哪些编译器可见、构建类型、MSVC 运行库、Qt 与 vcpkg 行为，详见下文参考。

### 2. 生成

```powershell
python generate.py
```

必须在**已具备所选编译器环境**的终端里运行（见「环境要求」）。每次生成都会**先删除再重建** `./<project.name>/`。

### 3. 配置、构建、安装

```powershell
cmake --preset msvc_x64_debug
cmake --build --preset build-msvc_x64_debug
cmake --install out/build/msvc_x64_debug
```

`cmake --list-presets` 可查看本机可见的预设。产物位于 `out/build/<preset>/artifacts/<Config>/<arch>/{bin,lib,pdb}`。

### 4. 运行测试

```powershell
ctest --preset test-msvc_x64_debug
```

测试预设始终存在；只有设置 `test_enabled = true`（注入 `include(CTest)` + `enable_testing()`）并注册用例后，`ctest` 才有东西可跑。

### Qt

```toml
[qt]
qt_enabled = true
sdk_dir = "D:/Qt/6.6.2/msvc2019_64"   # 留空 = 交给 Qt 默认搜索路径
components = ["Widgets"]
```

之后照常使用预设。Qt 在任何目标创建前完成查找；`AUTOMOC`/`AUTOUIC`/`AUTORCC` 已打开，Qt6 可执行目标会自动 finalize，子工程目录下的 `*.png/jpg/jpeg/svg/ico/ttf/webp/js/json/html` 会自动作为 Qt 资源嵌入。

### Linux

仓库自带的 `project.toml` 启用的是 `clang-cl`/`msvc`，在 Linux 上不适用——先把编译器换成 Linux 的：

```toml
[presets.user]
compilers = ["gcc", "clang"]
build_types = ["Debug", "Release"]
```

```bash
python3 generate.py
cmake --preset gcc_x64_debug
cmake --build --preset build-gcc_x64_debug
./out/build/gcc_x64_debug/artifacts/Debug/x64/bin/MyApp
```

`clang_x64_*` 预设会随同一份列表一起可见。预设的 `condition` 目前只覆盖 Windows 与 Linux 宿主。

## 环境要求与生成前预检

| 工具 | 要求 |
| --- | --- |
| Python | ≥ 3.11（依赖 `tomllib`） |
| CMake | ≥ 3.30；走原生 `import std` 路线需要 **≥ 4.4**（更低版本回退到 FILE_SET，clang-cl 必须 4.4） |
| Ninja | 在 `PATH` 中（也可用 `[presets].generator` 换生成器） |
| 编译器 | `[presets.user].compilers` 里列出的那些 |

**生成终端和配置终端必须看到同一套环境。** Public 层的 `base` 预设转发父进程环境：

```json
"environment": { "INCLUDE": "$penv{INCLUDE}", "LIB": "$penv{LIB}", "PATH": "$penv{PATH}" }
```

`$penv{}` 读取「调用 cmake 的那个进程」的环境，不会读取同一预设 `environment` 里刚定义的值（否则这里就是自引用）。`msvc-base` / `clang-cl-base` 使用外部架构策略，`cl.exe` / `clang-cl.exe` 需要 `INCLUDE`/`LIB` 定位 Windows SDK，`PATH` 还要能找到 `rc.exe`/`mt.exe`/`ninja`。请使用 *Developer PowerShell for VS*、先执行 `vcvars64.bat`，或使用干净的系统级环境。

生成前 `generate.py` 会检查所有「本平台适用且已启用」的编译器，任一不可用就**打印日志并中止**：

| 编译器 | 检查内容 |
| --- | --- |
| `msvc` | `PATH` 中有 `cl.exe`；`INCLUDE` 含 Windows Kits `ucrt` + `\um` + MSVC `vc\tools\msvc\…\include`；`LIB` 含对应条目且目录真实存在 |
| `clang-cl` | `PATH` 中有 `clang-cl.exe`；同样的 Windows SDK 检查 |
| `clang` | `PATH` 中有 `clang` 与 `clang++`；`<clang -print-resource-dir>/include` 存在；Windows 上另做 SDK 检查 |
| `gcc` | `PATH` 中有 `gcc` 与 `g++`；`g++ -print-file-name=include` 存在；`libstdc++.a` 可解析 |

已启用但不适用于本平台的编译器（如 Windows 上的 `gcc`）只报 `[SKIP]`，不拦截生成——它们的预设保持隐藏。

Linux 补充：`-fopenmp` 需要 libomp（Debian 上如 `libomp-19-dev`）；默认的 `import std` 示例需要自带 std 模块的工具链（MSVC 14.5x、libc++ 19+ 配合 `-stdlib=libc++`、GCC 15+）。GCC 14 不提供 `bits/std.cc`，请改用头文件版源码或更新的工具链。

**环境变量污染检测。** 含 `\n`/`\r` 或首尾空白的 `INCLUDE`/`LIB`（Windows）与 `PATH` 会被 `$penv{}` 原样带进编译命令行，产生 `LNK1104: cannot open file 'MSVCRTD.lib'` 之类难以定位的错误。预检会拦截并针对受影响的注册表作用域打印 PowerShell 修复命令。

## `project.toml` 参考

### `[project]`

| 键 | 类型 | 默认 | 作用 |
| --- | --- | --- | --- |
| `name` | string | —（必填） | 输出目录、CMake `project()` 名；`sub` 未命名时也作为子工程名 |
| `version` | string | `"1.0.0"` | `project(VERSION …)`，被子工程继承 |
| `description` | string | `""` | `project(DESCRIPTION …)`，被子工程继承 |
| `homepage_url` | string | `""` | `project(HOMEPAGE_URL …)` |
| `languages` | array | `["CXX"]` | `project(LANGUAGES …)`，如 `["C","CXX"]` |
| `c_standard` | int/string | `"17"` | 预设 `CMAKE_C_STANDARD`；同时烘焙进根 `CMakeLists.txt` 作为裸 `cmake -G Ninja` 的回退值 |
| `cxx_standard` | int/string | `"23"` | 预设 `CMAKE_CXX_STANDARD`；同样有回退值 |
| `jobs` | table | `{type="fixed", size=0}` | 并行度（见下） |
| `test_enabled` | bool | `false` | 在根 `CMakeLists.txt` 注入 `include(CTest)` + `enable_testing()` |

`jobs` 解析为整数 `JOBS`，供 build / test 预设使用：

- `type = "fixed"`：`size <= 0` → 全部可用核；否则 `min(size, 核数)`。
- `type = "factor"`：`size <= 0` → 全部核；否则 `clamp(round(核数 * min(size, 1.0)), 1, 核数)`。用 `round()` 避免 `100 * 0.29 == 28.999…` 被截成 28。
- 核数 = Linux 的 `sched_getaffinity`，其它平台 `os.cpu_count()`。
- 预设之外构建时，用 `CMAKE_BUILD_PARALLEL_LEVEL` **环境变量**控制并行度；它不是缓存变量。

`test_enabled = false` 仍会生成 test 预设，但没有 `enable_testing()`，`ctest` 找不到用例；不想开开关时，可自行取消根 `CMakeLists.txt` 里被注释的那两行。

### `[[project.sub]]`

不写时等价于一个空 `{}`，即单个 `src/` 目录。

| 键 | 类型 | 默认 | 作用 |
| --- | --- | --- | --- |
| `name` | string | `""` | 空 → 目录 `src/`、子工程名 = 主工程名；否则目录 = 名 = 子工程名 |
| `version` | string | 继承 | 子 `project(VERSION …)` |
| `description` | string | 继承 | 子 `project(DESCRIPTION …)` |
| `target_type` | string | `"EXE"` | `EXE` / `STATIC` / `SHARED` |
| `win32_executable` | bool | `true` | `WIN32_EXECUTABLE`（`true` = Windows 上不弹控制台） |
| `macos_bundle` | bool | `true` | `MACOSX_BUNDLE` |

每个子工程得到 `CMakeLists.txt`、`Dependencies.cmake`，以及按目标类型匹配的源码：`EXE` 用 `main.cpp`，库用 `library.cpp` + `library.h`。`modules/` 只作为示例拷贝一次，**不**接入构建。

仓库自带的 `project.toml` 为了示例更直观覆盖了两个默认值：`languages = ["C","CXX"]`、`win32_executable = false` / `macos_bundle = false`，保证示例保留控制台输出。

### `[presets]`

| 键 | 默认 | 作用 |
| --- | --- | --- |
| `binary_dir` | `${sourceDir}/out/build/${presetName}` | `base` 的 `binaryDir`；必须是相对路径、不含 `..`、且含 `${presetName}` |
| `architecture` | `"x64"` | `x64` / `x86` / `arm` / `arm64`；参与预设名、`architecture.value` 与 IntelliSense 模式 |
| `generator` | `"Ninja"` | 已知生成器名，或 `Visual Studio <n> <yyyy>` |
| `msvc_runtime_mode` | `"MD"` | `MD`（动态 CRT）/ `MT`（静态 CRT）；同时决定 vcpkg 静态 triplet |
| `msvc_toolset` | `"v145"` | `msvc-base` 的 toolset（VS 2022 用 `v143`） |
| `use_sanitizers` | `false` | 所有预设的 `USE_SANITIZERS=ON/OFF`（仅 Clang/GCC） |

### `[presets.user]`

| 键 | 默认 | 作用 |
| --- | --- | --- |
| `compilers` | — | `msvc`/`clang-cl`/`clang`/`gcc` 的子集，决定哪些编译器预设可见 |
| `build_types` | — | `Debug`/`RelWithDebInfo`/`Release`/`MinSizeRel` 的子集，决定哪些构建类型可见 |
| `install_dir` | `${sourceDir}/out/install/${presetGroup}` | 隐藏的 `-local` 预设的 `installDir`；`${presetGroup}` = `<compiler>_<arch>` |

### `[qt]`

| 键 | 默认 | 作用 |
| --- | --- | --- |
| `qt_enabled` | `false` | `option(QT_SUPPORT …)` 的默认值；同时决定是否注入 Qt Creator vendor 块 |
| `sdk_dir` | `""`（空） | `QT_SDK_DIR` 默认值，追加进 `CMAKE_PREFIX_PATH`。仓库自带 `project.toml` 里填的是示例路径 |
| `components` | `["Widgets"]` | `find_package(Qt … COMPONENTS …)` 的组件 |
| `presets_checksum` | `""` | 根级 `qt-project.org/Presets` 的 vendor checksum；留空则不生成该块 |
| `qt_checksum` | `""` | `base` 内 `qt-project.org/Qt` 的 checksum；留空则不生成 |

这两个 checksum 是 Qt Creator 针对本机 Qt 安装写入的簿记值，换机器或升级 Qt 后更新或清空即可；`qt_enabled = false` 时两者都会被忽略。

## 生成产物结构

```
MyApp/
├── CMakeLists.txt              # 根：模块 include、project()、CTest 接线、子目录
├── CMakePresets.json           # Public 预设层（可共享）
├── CMakeUserPresets.json       # User 预设层（可见预设、installDir）
├── cmake/
│   ├── CompilerId.cmake        # 编译器家族标志 + MSVC_RUNTIME_MODE
│   ├── Platform.cmake          # OS / 架构、imported config 映射、默认构建类型
│   ├── CompilerOptions.cmake   # scaffold_configure_target()：编译选项、按配置选项
│   ├── OutputLayout.cmake      # artifacts/<config>/<arch>/{bin,lib,pdb}
│   ├── TargetUtils.cmake       # CopyTargetDependentLibs()、IMPORTED_LIBRARY()
│   ├── Vcpkg.cmake             # vcpkg 根/triplet 推导 + FindVcpkgPackage()（可选）
│   ├── PrebuiltLibraries.cmake # scaffold_add_prebuilt_library()（可选）
│   ├── QtSupport.cmake         # QT_SUPPORT、SDK 路径、find_package(Qt6/Qt5)
│   ├── ImportStd.cmake         # import std;（pre-project UUID、扫描补偿）
│   ├── ProjectTarget.cmake     # 目标创建 / Qt 资源 / finalize / 安装
│   ├── ProtoGen.cmake          # scaffold_protobuf_generate()（C++/C#/Java/Python）
│   └── ShowIncludesPrefix.cmake# MSVC+Ninja 依赖前缀（仅 CMake < 4.4）
├── .clang-format  .clang-tidy  .clangd
├── .vscode/                    # launch.json、settings.json、semantic-rules.json
├── .gitignore
├── modules/                    # C++ 模块示例库（math.cppm + math.cpp），默认不构建
│   ├── CMakeLists.txt
│   ├── math.cppm
│   └── math.cpp
└── src/
    ├── CMakeLists.txt          # project() + 目标 + 选项 + 安装
    ├── Dependencies.cmake      # 三方依赖配方（8 节）
    └── main.cpp                # EXE 入口；使用 import std;
```

示例目标是 C++23 可执行文件，开头就是 `import std;`。`math` 模块库需要在根 `CMakeLists.txt` 加 `add_subdirectory(modules)`、并在 `src/CMakeLists.txt` 取消 `target_link_libraries(... math)` 的注释后才会参与构建。

## 模板内部（`cmake/`）

根 `CMakeLists.txt` 是一段很短的骨架：

```cmake
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(ImportStd)        # 必须在 project() 之前：设置 import std 的实验 UUID
project(...)
include(CompilerId Platform ShowIncludesPrefix OutputLayout TargetUtils QtSupport ProtoGen)
# include(Vcpkg) / include(PrebuiltLibraries)  # 按需启用
```

| 模块 | 职责 |
| --- | --- |
| `CompilerId` | 定义 `COMPILER_MSVC`、`COMPILER_CLANG`、`COMPILER_CLANG_CL`、`COMPILER_GCC`、`COMPILER_MSVC_LIKE`；把 `MSVC_RUNTIME_MODE`（MD/MT）映射到 `CMAKE_MSVC_RUNTIME_LIBRARY` |
| `Platform` | `PLATFORM_NAME`、`LIB_SUFFIX`、`SHARED_LIB_SUFFIX`、`PLATFORM_SUFFIX`（`x64`/`x86`/`arm`/`arm64`）；把 RelWithDebInfo/MinSizeRel 的 imported config 映射到 Release；单配置生成器在未指定时默认 `CMAKE_BUILD_TYPE=Debug`，且不再强行改写 `CMAKE_CONFIGURATION_TYPES` |
| `CompilerOptions` | `scaffold_configure_target(<target>)`：MSVC 选项集（`/std:c++latest /utf-8 /permissive- /W4 /arch:AVX2 /openmp:experimental /bigobj …`）或 GCC/Clang 选项集（`-std=c++… -Wall -Wextra -Werror -mavx2 -mfma -fopenmp …`）；用 `$<CONFIG:…>` 表达 Debug/Release/RelWithDebInfo；4 MiB 栈；sanitizer；ccache（GCC/Clang）；MSVC 系编译器加 `DEBUG_POSTFIX d` 与 PDB 命名 |
| `OutputLayout` | 运行库/静态库/PDB 输出统一到 `artifacts/$<CONFIG>/$<arch>/…`，多配置生成器也能按配置分树 |
| `TargetUtils` | `CopyTargetDependentLibs(target names release_dir [debug_dir])` 把运行时 DLL 拷到可执行文件旁（Debug 先试 `<name>d.dll`，Linux 支持带版本号的 `.so`）；`IMPORTED_LIBRARY(target base dir)` 封装手工分发的动态库 |
| `Vcpkg` | 推导 `VCPKG_ROOT`（toolchain 文件 → 缓存/环境 → 平台约定），按 `MSVC_RUNTIME_MODE` 选择 `VCPKG_STATIC_TRIPLET`（`<arch>-windows-static[-md]`），导出 `VCPKG_*_PATH`，并提供 `FindVcpkgPackage()` |
| `PrebuiltLibraries` | `scaffold_add_prebuilt_library(<target> [STATIC] INCLUDE_DIR … [DEBUG_LOCATION/IMPLIB] [RELEASE_LOCATION/IMPLIB] …)` 创建 `IMPORTED GLOBAL` 目标与 `<name>::<name>` 别名；单配置库自动回退为通用 location。附带由 `THIRD_PARTY_ROOT` 驱动的示例 |
| `QtSupport` | `option(QT_SUPPORT …)`、`AUTOMOC/AUTOUIC/AUTORCC`、`QT_SDK_DIR` → `CMAKE_PREFIX_PATH`、`find_package(Qt6/Qt5 …)` |
| `ImportStd` | 在 `project()` 之前按 CMake 版本设置 `CMAKE_EXPERIMENTAL_CXX_IMPORT_STD`；`scaffold_enable_import_std(<target>)` 在 CMake ≥ 4.4 用 `CXX_MODULE_STD`，< 4.4 回退到 `FILE_SET std`（只允许一个目标使用该回退）；`scaffold_mark_sources_for_module_scanning()` 为非生成源补开模块扫描 |
| `ProjectTarget` | `scaffold_add_project_target()`（EXE/STATIC/SHARED，含 Qt5/6 分支）、`scaffold_add_qt_resources()`、`scaffold_finalize_project_target()`（Qt6 可执行目标 + 扫描补偿）、`scaffold_install_project_target()` |
| `ProtoGen` | `scaffold_protobuf_generate()`：protobuf/gRPC 代码生成 |
| `ShowIncludesPrefix` | 仅在 CMake < 4.4 + MSVC + Ninja 时重新探测本地化 `/showIncludes` 前缀；≥ 4.4 直接返回，因为 CMake 自带该机制（把原始代码页字节写进去会让 `rules.ninja` 静默缺失） |

### `import std;` 说明

- CMake ≥ 4.4 由 CMake 自己供给 std 模块，`scaffold_enable_import_std()` 只设置 `CXX_MODULE_STD`。
- CMake < 4.4 把编译器自带的 std 模块源码作为 `FILE_SET std` 加入，只允许一个目标这样做；clang-cl 会直接报错（请改用 MSVC/Clang 或升级 CMake）。
- 含 `GENERATED` 源的目标（Qt AUTOMOC、proto 生成）默认按 unscanned 规则编译，会破坏 `import std;`。`ProjectTarget` 与 `ProtoGen` 都会对受影响源重设 `CXX_SCAN_FOR_MODULES ON`。
- 在 CMake ≥ 4.4 + Ninja 下 `OutputLayout` 是承重结构：它让合成的 std provider 库不落在 build 根目录，否则 `@cmake_cxx_std.lib` 会被 `vs_link_exe` 误当成响应文件，链接报 `LNK2001`。

### `scaffold_protobuf_generate()`

```cmake
scaffold_protobuf_generate(echo_proto
    PROTO_FILES "${CMAKE_CURRENT_SOURCE_DIR}/proto/echo.proto"
    LANGUAGES CPP                 # CPP | CSHARP | JAVA | PYTHON（默认 CPP）
    GRPC                          # 同时生成服务桩
    TARGET ${PROJECT_NAME}        # 把生成的 C++ 源挂到目标
)
target_link_libraries(${PROJECT_NAME} PRIVATE protobuf::libprotobuf gRPC::grpc++)
```

- 默认输出到 `${CMAKE_BINARY_DIR}/generated/proto/{cpp,csharp,java,python}`。
- C++ 是真实构建规则（增量、缺文件可重生成）；其它语言因文件名依赖 package/message 名，每种语言用一个 stamp。custom target 带 `ALL`，默认构建就会产出所有请求的语言。
- 工具顺序：显式参数 → `SCAFFOLD_*` 缓存变量 → 导入目标（`protobuf::protoc`、`gRPC::grpc_cpp_plugin`、`gRPC::grpc_csharp_plugin`）→ `<VCPKG_ROOT>/installed/*/tools/{protobuf,grpc}` → `PATH`。`protoc-gen-grpc-java` 需要单独下载。
- 向调用方导出 `<name>_SOURCES`、`<name>_INCLUDE_DIRS`、`<name>_OUTPUT_DIR`。

## 预设模型与命名

Public 层（`CMakePresets.json`）：

- `base`：标准、生成器、`binaryDir`、外部架构策略、`$penv{}` 环境、`CMAKE_EXPORT_COMPILE_COMMANDS`、`CMAKE_FIND_PACKAGE_PREFER_CONFIG`
- `msvc-base` / `clang-cl-base` / `clang-base` / `gcc-base`：编译器变量、toolset、宿主 `condition`、IntelliSense vendor 设置
- `build-base`：`jobs`；`test-base`：`outputOnFailure` + `execution.jobs`

User 层（`CMakeUserPresets.json`）：

- `<compiler>-<arch>-local`：隐藏，承载 `installDir`
- `<compiler>_<arch>_<buildtype>`：可见的 configure 预设（如 `msvc_x64_debug`）
- `build-<compiler>_<arch>_<buildtype>` 与 `test-<compiler>_<arch>_<buildtype>`

configure / build / test 三层预设的 `hidden` 会被统一改写：编译器不在 `compilers` 或构建类型不在 `build_types` 中就隐藏。

## 占位符 `#{…}`

`generate.py` 对模板文件做单遍正则替换：

- 全局：`MAIN_PROJECT_NAME`、`PROJECT_VERSION`、`PROJECT_DESCRIPTION`、`PROJECT_HOMEPAGE_URL`、`PROJECT_LANGUAGES`、`C_STANDARD`、`CXX_STANDARD`、`GENERATOR`、`BINARY_DIR`、`ARCHITECTURE`、`MSVC_RUNTIME_MODE`、`MSVC_TOOLSET`、`JOBS`、`INSTALL_DIR`
- 每个 sub：`SUB_PROJECT_NAME`、`SUB_PROJECT_VERSION`、`SUB_PROJECT_DESCRIPTION`、`TARGET_TYPE`、`MACOS_BUNDLE`、`WIN32_EXECUTABLE`
- 根 `CMakeLists.txt`：`QT_SUPPORT_DEFAULT`、`QT_SDK_DIR`、`QT_COMPONENTS`、`TESTING_SETUP`
- 预设：`QT_VENDOR_BASE`、`QT_VENDOR_ROOT`（对应 checksum 为空时展开为空；占位符自带前导逗号，JSON 仍合法）
- `cmake/*.cmake` 也会被渲染，因此模块里的默认值同样可以携带占位符

语义：单遍替换（值里的 `#{OTHER}` 不会被二次展开）；进入 CMake 引号串的值（`*_DESCRIPTION`、`homepage_url`、`sdk_dir`）转义 `\`、`"`、`;` 与控制字符；进入 JSON 的值走 JSON 转义；未知占位符直接报错；生成后扫描产物，残留 `#{…}` 会指出文件并终止。

## 输入校验

`generate.py` 在写文件之前校验 `project.toml`，失败时输出一行 `Error: …` 并以退出码 1 结束，不会把问题带到 CMake 阶段：

| 位置 | 规则 |
| --- | --- |
| `project.name` | 单段路径名（`[A-Za-z_][A-Za-z0-9._+-]*`，不以 `.` 结尾）；输出目录必须位于仓库内 |
| `project.version` | 单个 token（无空白、引号、反斜杠、`;`、`#`、花括号） |
| `project.languages` | 非空数组，每项为单 token |
| `project.homepage_url` | 不含换行 |
| `project.jobs` | `type` ∈ `fixed`/`factor`；`size` 为整数（fixed）或数字（factor）；布尔/字符串一律拒绝 |
| `[[project.sub]].name` | 同 `project.name`；不重复（大小写不敏感）；不能占用 `cmake`、`modules` |
| `[[project.sub]].target_type` | `EXE` / `STATIC` / `SHARED` |
| `[[project.sub]].win32_executable` / `macos_bundle` | 必须是布尔 |
| `[presets]` | `architecture`、`generator`、`msvc_runtime_mode`、`msvc_toolset`、`binary_dir` |
| `[presets.user]` | `compilers` / `build_types` 必须是已知名称（大小写不敏感） |
| `[qt].components` | 非空数组，每项为单 token |

`project.toml` 允许带 UTF-8 BOM；TOML/JSON 解析失败会给出文件名与原因。

## 扩展指南

**新增构建类型** → 在 `template/CMakeUserPresets.json` 为该类型补 configure/build/test 预设，把名字登记到 `generate.py` 的 `ALL_BUILD_TYPES`，再写进 `[presets.user].build_types`。

**新增编译器** → 三处对齐：`template/CMakePresets.json` 的 `<comp>-base`；`template/CMakeUserPresets.json` 的 `<comp>-<arch>-local` 与各构建类型预设；`generate.py` 的 `ALL_COMPILERS`、`COMPILER_KEYWORDS`（更具体的关键字在前）、`COMPILER_CHECKS`、`HOST_COMPILERS`。

**新增生成器** → 加入 `generate.py` 的 `KNOWN_GENERATORS`（Visual Studio 名称按模式接受）。

**接入三方库** → 编辑生成的 `src/Dependencies.cmake`（或 `template/src/Dependencies.cmake`）：vcpkg（`include(Vcpkg)` + `FindVcpkgPackage(...)`）、`find_package`，或 `scaffold_add_prebuilt_library(...)`。运行时 DLL 拷贝用 `CopyTargetDependentLibs()`。

**生成 proto 代码** → 在 `src/Dependencies.cmake` 或 `src/CMakeLists.txt` 调用 `scaffold_protobuf_generate()`；生成后的 `Dependencies.cmake` 第 8 节有完整配方。

## 已知限制

- **模板不带测试用例。** `template/` 没有 `add_test()`；需要自己打开 `test_enabled` 并注册测试。
- **`import std;` 依赖工具链。** MSVC 14.5x 可用；CMake < 4.4 需要编译器自带 std 模块且只允许一个 std FILE_SET 目标；clang-cl 必须 CMake ≥ 4.4；Clang 需要 libc++（或自带 std 模块的 libstdc++）；GCC 需要 15+。
- **预设的 `condition` 只覆盖 Windows 与 Linux。** `msvc`/`clang-cl` 要求 Windows，`gcc` 要求 Linux，`clang` 限定 Windows/Linux；macOS 尚未接线。
- **x86-64 基线。** `CompilerOptions.cmake` 固定了 `/arch:AVX2` / `-mavx2 -mfma`；使用 ARM 预设时需要调整这一段。
- **GCC/Clang 默认 `-Werror`。** 任何警告都会中断构建；如果对现有代码太严格，可在 `CompilerOptions.cmake` 里放宽。
- **`modules/` 是可选示例。** 加 `add_subdirectory(modules)` 并取消链接行注释后才会构建。
- **重新生成会删除输出目录。** 手写文件请放在目录之外（或 `[[project.sub]]` 之外）；目录被占用时生成会报错终止，而不是继续写入旧树。
- **不要在 `project.toml` 的值里写字面 `#{…}`**，否则产物残留断言会失败。
- **vcpkg Debug + gRPC 排查。** 如果 Debug 下链接 gRPC 生成代码报 `LNK1000: Internal error during LIB::Search`，而 Release 正常，请先用一个不含本脚手架的最小工程复现；这指向 vcpkg Debug 库集/链接器，而不是模板。

## 仓库结构

```
generate.py          # 生成器
project.toml         # 生成输入
quick-generate.bat   # python generate.py
template/            # 由 generate.py 渲染的工程骨架
docs/                # clangd / clang-tidy / VS Code / 主题色指南；docs/prompt/
.agent/skills/       # AI 协作技能库
LICENSE
README.md            # 英文说明
README.zh.md         # 中文说明（本文件）
```
