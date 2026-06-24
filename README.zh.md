# cmake-arithmetic

[English](README.md) | **简体中文**

TOML 驱动的现代 C++ CMake 工程生成器。改一个 `project.toml`，就把 `template/` 骨架渲染成可直接构建的 C++ 工程：可移植的预设、多编译器支持（MSVC、Clang、GCC、clang-cl）、可选 Qt 与 vcpkg、C++ 模块、clang 工具链配置，并把可共享的框架设置与本机路径严格分离。

---

## 这是什么

`generate.py` 读取同目录下的 `project.toml`，把 `template/` 里的骨架渲染成一份可直接构建的 C++ 工程，输出到 `./<project.name>/`。

设计上把 CMake 预设拆成两层：

- **`CMakePresets.json`（Public / 框架层）**：编译器基座、标准版本、工具集、架构策略等**可共享**内容，不含任何本机路径。
- **`CMakeUserPresets.json`（User / 本机层）**：编译器 × 架构 × 构建类型的可见预设、`installDir`、以及本机环境。可随机器不同而不同。

`generate.py` 只做「文本占位符替换 + 按 `project.toml` 开关预设可见性」，不会把本机 SDK 路径烘进 Public 预设。

## 快速开始

```powershell
# 1. 编辑 project.toml
# 2. 生成（在已具备所选编译器环境的终端里运行，见下节）
python generate.py
# 3. 构建 / 安装
cmake --preset msvc_x64_debug
cmake --build --preset build-msvc_x64_debug
cmake --install out/build/msvc_x64_debug
# 4. 测试（需在 project.toml 的 [project] 中设置 test_enabled = true）
ctest --preset test-msvc_x64_debug
```

生成后 `./MyApp/` 即完整工程；改 `project.toml` 后重新运行 `generate.py` 会**先删除**旧输出目录再重建。删除失败（目录被占用、只读等）会直接报错终止，不会继续往旧目录里写文件。

## 环境要求与生成前预检

**工具链**：Python ≥ 3.11（依赖 `tomllib`）、CMake ≥ 3.30、Ninja，以及 `[presets.user].compilers` 里启用的编译器。

**关键约定：Public 预设不烘焙本机路径。** `CMakePresets.json` 的 `base` 预设用宏引用父进程环境：

```json
"environment": {
  "INCLUDE": "$penv{INCLUDE}",
  "LIB": "$penv{LIB}",
  "PATH": "$penv{PATH}"
}
```

- `$penv{}` 只在 **configure 时**从「调用 cmake 的那个进程」的环境读取，**不会**读取同一预设里 `environment` 定义的值（那是 `$env{}` 的行为）。因为这里重定义的就是 `INCLUDE/LIB/PATH` 自身，用 `$env{}` 会构成循环引用，所以必须用 `$penv{}`。
- 为什么需要这三个变量：`msvc-base` / `clang-cl-base` 使用 `"architecture": {"strategy": "external"}` 与外部 toolset，CMake/Ninja 会**直接调用 `cl.exe`/`clang-cl.exe`**，此时编译器需要从环境拿到 Windows SDK 的 `INCLUDE`/`LIB`/`PATH`。（`PATH` 还需能找到 `rc.exe`、`mt.exe`、`ninja`。）

因此：**`python generate.py` 和 `cmake --preset …` 都必须在同一类环境里执行** —— 例如「Developer PowerShell for VS」，或先 `vcvars64.bat`，或把干净的 `INCLUDE`/`LIB`/`PATH` 持久化到系统中。

`generate.py` 在生成前会做预检，任一「本平台适用且已启用」的编译器不可用即**中止并打印日志**（`exit 1`）：

| 编译器 | 检查内容 |
| ------ | -------- |
| `msvc` | PATH 中有 `cl.exe`；`INCLUDE` 含 Windows Kits `ucrt` + `\um` + MSVC `vc\tools\msvc\…\include`；`LIB` 含对应 `ucrt`/`\um`/`lib`，且目录真实存在 |
| `clang-cl` | PATH 中有 `clang-cl.exe`；同上的 Windows SDK 检查 |
| `clang` | PATH 中有 `clang` 与 `clang++`；`clang -print-resource-dir` 下的 `include` 存在；Windows 上另做 SDK 检查 |
| `gcc` | PATH 中有 `gcc` 与 `g++`；`g++ -print-file-name=include` 存在；`libstdc++.a` 可解析 |

不适用于本平台的已启用编译器（如 Windows 上启用 `gcc`）只打 `[SKIP]`，不拦截——它们在模板里本就带 `condition` 会被 CMake 隐藏。

**换行污染检测**：环境变量若含 `\n`/`\r` 或首尾空白，会被 `$penv{}` 原样带进编译命令行，导致链接器报 `LNK1104: cannot open file 'MSVCRTD.lib'` 之类的怪错。预检会拦截并给出修复命令：

```
Environment check: polluted environment variable(s) detected:
  - LIB: 含换行符 (LF/CR)
This breaks $penv{} expansion; the linker receives a path that carries a newline.
Fix in an elevated PowerShell, then restart the terminal:
  [Environment]::SetEnvironmentVariable('LIB', ([Environment]::GetEnvironmentVariable('LIB','Machine') -split ';' | ForEach-Object {($_ -replace '\r|\n','').Trim()} | Where-Object {$_}) -join ';', 'Machine')
```

## project.toml 完整参考

### `[project]`

| 键 | 类型 | 默认 | 作用 |
| --- | --- | --- | --- |
| `name` | string | —（必填、非空） | 输出目录名、CMake `project()` 名、以及 `sub` 未命名时的子工程名 |
| `version` | string | `"1.0.0"` | `project(VERSION …)`，并被未指定版本的 sub 继承 |
| `description` | string | `""` | `project(DESCRIPTION …)`，并被未指定描述的 sub 继承 |
| `homepage_url` | string | `""` | `project(HOMEPAGE_URL …)` |
| `languages` | array | `["CXX"]` | `project(LANGUAGES …)`，如 `["C","CXX"]` |
| `c_standard` | int/string | `"17"` | 写入预设 `CMAKE_C_STANDARD` |
| `cxx_standard` | int/string | `"23"` | 写入预设 `CMAKE_CXX_STANDARD` |
| `jobs` | table | `{type="fixed", size=0}` | 并行度，见下 |
| `test_enabled` | bool | `false` | `true` 时在根 `CMakeLists.txt` 注入 `include(CTest)` + `enable_testing()`，见下 |

`jobs` 解析为整数 `JOBS`，同时用于 `set(CMAKE_BUILD_PARALLEL_LEVEL #{JOBS})` 与 build 预设的 `"jobs"`：

- `type = "fixed"`：`size <= 0` → 取本机可用核数；否则 `min(size, 核数)`。
- `type = "factor"`：`size <= 0` → 取核数；否则 `clamp(round(核数 * min(size,1.0)), 1, 核数)`。用 `round()` 而非截断，避免 `100 * 0.29 == 28.999…` 被截成 28。
- 核数 = Linux 的 `sched_getaffinity` 计数，其它平台用 `os.cpu_count()`。

`test_enabled`：`true` 时在根 `CMakeLists.txt` 注入 `include(CTest)` + `enable_testing()`，`false` 时注入一段注释提示。`testPresets` **无论该开关如何都会生成**；关闭时根 `CMakeLists.txt` 没有 `enable_testing()`，`ctest --preset …` 找不到任何用例，此时可自行在根 `CMakeLists.txt` 取消那两行注释解决。

### `[[project.sub]]`

数组表；**不写** `[[project.sub]]` 时等价于一个空的 `{}`，即单个子目录 `src/`。

| 键 | 类型 | 默认 | 作用 |
| --- | --- | --- | --- |
| `name` | string | `""` | 空 → 目录 `src/` 且子工程名 = 主工程名；非空 → 目录 = 名 = 子工程名 |
| `version` | string | 继承 `project.version` | 子 `project(VERSION …)` |
| `description` | string | 继承 `project.description` | 子 `project(DESCRIPTION …)` |
| `target_type` | string | `"EXE"` | `EXE`/`STATIC`/`SHARED`，决定 `add_executable` 还是 `add_library` |
| `win32_executable` | bool | `true` | 目标 `WIN32_EXECUTABLE`（`true` 时 Windows 上不弹控制台） |
| `macos_bundle` | bool | `true` | 目标 `MACOSX_BUNDLE` |

每个 sub 会得到 `CMakeLists.txt`、`Dependencies.cmake`，以及 `template/src/` 下其余文件（`main.cpp` 等）的拷贝；`modules/` 来自 `template/modules/`，只拷贝一次到产物根目录作为**示例**，默认不接入构建（见下）。

### `[presets]`

| 键 | 默认 | 作用 |
| --- | --- | --- |
| `binary_dir` | `${sourceDir}/out/build/${presetName}` | `base` 预设 `binaryDir`；必须是相对路径、不含 `..`、且含 `${presetName}`（否则所有预设共用一棵构建树） |
| `architecture` | `"x64"` | 架构值，参与预设名、`architecture.value` 与 `intelliSenseMode`（`windows-msvc-<arch>`）；仅接受 `"x64"`、`"x86"`、`"arm"`、`"arm64"`（CMake `-A` 的别名写法，大小写不敏感） |
| `generator` | `"Ninja"` | 生成器；必须是 `KNOWN_GENERATORS` 之一，或 `Visual Studio <n> <yyyy>` 形式 |
| `msvc_runtime_mode` | `"MD"` | `MSVC_RUNTIME_MODE` 缓存变量（`MD`/`MT`，见 `cmake/VcpkgConfig.cmake`） |
| `msvc_toolset` | `"v145"` | `msvc-base` 的 `toolset.value`（clang-cl 固定为 `ClangCL`） |
| `use_sanitizers` | `false` | 所有预设的 `USE_SANITIZERS` = `ON`/`OFF` |

### `[presets.user]`

| 键 | 默认 | 作用 |
| --- | --- | --- |
| `compilers` | — | 取值为 `msvc`/`clang`/`gcc`/`clang-cl` 的数组；决定哪些编译器预设**可见**，其余置 `hidden` |
| `build_types` | — | 取值为 `Debug`/`RelWithDebInfo`/`Release`/`MinSizeRel` 的数组；决定哪些构建类型**可见** |
| `install_dir` | `${sourceDir}/out/install/${presetGroup}` | `-local` 预设的 `installDir`；`${presetGroup}` = `<compiler>_<arch>` |

### `[qt]`

| 键 | 默认 | 作用 |
| --- | --- | --- |
| `qt_enabled` | `false` | 根 `CMakeLists.txt` 中 `option(QT_SUPPORT …)` 的默认值（`ON`/`OFF`），并决定 `CMakePresets.json` 两个 Qt Creator vendor 占位符是否注入 |
| `sdk_dir` | `D:/Qt/6.6.2/msvc2019_64` | `QT_SDK_DIR` 缓存变量默认值，仅 `QT_SUPPORT=ON` 时用到 |
| `components` | `["Widgets"]` | `find_package(Qt … COMPONENTS …)` 组件列表 |
| `presets_checksum` | `""` | 根级 vendor `qt-project.org/Presets` 的 `checksum`；留空则整块不生成 |
| `qt_checksum` | `""` | `base` 内 vendor `qt-project.org/Qt` 的 `checksum`；留空则整块不生成 |

> 这里**不再有** `qt-base` / `non-qt-base` 预设，Qt 开关走 `option(QT_SUPPORT …)` 的默认值。Qt 的查找路径由根 `CMakeLists.txt` 把 `sdk_dir` 作为 `QT_SDK_DIR` 追加进 `CMAKE_PREFIX_PATH` 提供，不依赖 `QTDIR` 环境变量（已实测 `QTDIR` 未设置时仍能配置并构建 Qt 目标）。
>
> 两个 `checksum` 是 Qt Creator 自己写进预设的簿记值，与本机 Qt 安装绑定。仓库自带的 `project.toml` 里填的是本机实测值；换机器/升级 Qt 后按 Creator 写出的新值更新即可，或留空以不再生成该 vendor 块。

## 生成产物

```
MyApp/
├── CMakeLists.txt              # 由 template/CMakeLists.txt 渲染（含 test_enabled 决定的 CTest 接线 + add_subdirectory(<sub>…)）
├── CMakePresets.json           # Public 层（框架/可共享）
├── CMakeUserPresets.json       # User 层（本机可见预设）
├── cmake/                      # PlatformConfig / TargetCompilerFlags / CxxModules / VcpkgConfig …
├── .clang-format .clang-tidy .clangd
├── .vscode/                    # 原样拷贝自 template（launch.json, settings.json, semantic-rules.json）
├── .vs/settings.json
├── .gitignore
├── modules/                    # C++ 模块示例库（math：math.cppm 模块接口 + math.cpp 实现）
│   ├── CMakeLists.txt          # project(math) + add_library(math STATIC) + CXX_MODULES file set
│   ├── math.cppm
│   └── math.cpp
└── src/                        # 每个 sub 一个目录
    ├── CMakeLists.txt          # project() + add_executable/library + install
    ├── Dependencies.cmake      # 三方库接入点
    └── main.cpp
```

`modules/` 仅作**示例**，默认**不**接入构建：根 `CMakeLists.txt` 不会 `add_subdirectory(modules)`，`src/CMakeLists.txt` 里的 `target_link_libraries(${PROJECT_NAME} PRIVATE math)` 也处于注释状态。需要时在根 `CMakeLists.txt` 加 `add_subdirectory(modules)` 并取消该行注释即可。示例库自身**不** `import std;`（只用 `#include <cmath>`），因此不会与主目标抢同一个 std 模块。

## 预设模型与命名

**Public 层**（`CMakePresets.json`）：

- `base`：标准/生成器/`binaryDir`/`architecture(外部策略)`/`environment($penv{})`
- `msvc-base` / `clang-cl-base` / `clang-base` / `gcc-base`：编译器与 toolset，各带 `condition` 按宿主 OS 隐藏
- `build-base`：`"jobs"`
- `test-base`：`output.outputOnFailure` + `execution.jobs`

**User 层**（`CMakeUserPresets.json`）：

- `<compiler>-<arch>-local`：隐藏，承载 `installDir`，继承 `<compiler>-base`
- `<compiler>_<arch>_<buildtype>`：可见的 configure 预设（`buildtype` 小写，如 `msvc_x64_debug`）
- `build-<compiler>_<arch>_<buildtype>`：对应的 build 预设
- `test-<compiler>_<arch>_<buildtype>`：对应的 test 预设（继承 `test-base`，`configurePreset` 指向同名 configure 预设）

`generate.py` 对 `configurePresets` / `buildPresets` / `testPresets` 中**带构建类型**的预设统一改写 `hidden`：编译器不在 `compilers` 或构建类型不在 `build_types` 中即隐藏，三层预设可见性始终一致。（测试预设要能真正跑起来还需 `[project] test_enabled = true`。）

## 占位符 `#{…}`

`generate.py` 对模板文件做**单遍**正则替换（`#{KEY}` → 值）：

- 全局：`MAIN_PROJECT_NAME`、`PROJECT_VERSION`、`PROJECT_DESCRIPTION`、`PROJECT_HOMEPAGE_URL`、`PROJECT_LANGUAGES`、`GENERATOR`、`BINARY_DIR`、`ARCHITECTURE`、`MSVC_RUNTIME_MODE`、`MSVC_TOOLSET`、`JOBS`
- 每个 sub：`SUB_PROJECT_NAME`、`SUB_PROJECT_VERSION`、`SUB_PROJECT_DESCRIPTION`、`TARGET_TYPE`、`MACOS_BUNDLE`、`WIN32_EXECUTABLE`
- 根 `CMakeLists.txt`：`#{QT_SUPPORT_DEFAULT}`、`#{QT_SDK_DIR}`、`#{QT_COMPONENTS}`、`#{TESTING_SETUP}`
- `CMakePresets.json`：`#{QT_VENDOR_BASE}`（`base` 内）、`#{QT_VENDOR_ROOT}`（根级）；`qt_enabled` 为真且 `[qt]` 对应 `checksum` 非空时注入 Qt Creator 的 vendor 块，否则展开为空（占位符自带前导逗号，故为空时 JSON 仍合法）
- `CMakeUserPresets.json`：`#{INSTALL_DIR}` 由 `[presets.user].install_dir` 提供初值，随后每个 `<compiler>-<arch>-local` 预设都会被写入 `${presetGroup}` 展开后的具体路径（编译器名识别不出来时退化为预设名本身）

替换语义（与常见的“逐键 `str.replace`”不同）：

- **单遍替换**：值里若含 `#{OTHER}` 不会被二次展开。
- **按上下文转义**：进入 CMake 引号串的值（`*_DESCRIPTION`、`homepage_url`、`sdk_dir`）会转义 `\` `"` `;` 与换行；进入 JSON 的值走 JSON 转义。
- **未知占位符直接报错**：模板里出现替换表以外的 `#{…}`（拼错 key）会 `Error: unknown placeholder(s) …` 并终止，不再静默残留。
- **产物残留断言**：生成结束后扫描输出目录，若仍有 `#{…}`（例如某个 `project.toml` 值里写了字面 `#{…}`）会报错并指出文件。

## 输入校验

`generate.py` 对 `project.toml` 做白名单校验，出错时输出一行 `Error: …` 并以 exit 1 终止，而不是把问题带到 CMake 阶段：

| 位置 | 校验 |
| --- | --- |
| `project.name` | 单段目录名：`[A-Za-z_][A-Za-z0-9._+-]*`、不以 `.` 结尾（禁止 `..`、`/`、`\`、盘符）；生成前还会再断言输出目录位于仓库内 |
| `project.version` | 单个 token（无空白、引号、反斜杠、`;`、`#`、花括号） |
| `project.languages` | 非空数组，每项为单 token |
| `project.homepage_url` | 不含换行 |
| `project.jobs` | `type` ∈ `fixed`/`factor`；`size` 为整数（fixed）或数字（factor），`bool`/字符串一律拒绝 |
| `[[project.sub]].name` | 同 `project.name`；不得重复（大小写不敏感）；不得占用 `cmake`/`modules`（生成器自己写的根级目录） |
| `[[project.sub]].target_type` | `EXE`/`STATIC`/`SHARED` |
| `[[project.sub]].win32_executable` / `macos_bundle` | 必须是布尔 |
| `[presets]` | 见上表：`architecture`/`generator`/`msvc_runtime_mode`/`msvc_toolset`/`binary_dir` |
| `[presets.user].compilers` / `build_types` | 必须是 `ALL_COMPILERS` / `ALL_BUILD_TYPES` 的子集（大小写不敏感） |
| `[qt].components` | 非空数组，每项为单 token |

`project.toml` 允许带 UTF-8 BOM（读取时自动剥离）；TOML/JSON 解析失败会给出文件名与原因，不再抛裸回溯。

## 扩展指南

**新增构建类型** → 在 `template/CMakeUserPresets.json` 为每个编译器加一组 configure/build/test 预设，把名字加进 `generate.py` 的 `ALL_BUILD_TYPES`（校验会拒绝未登记的名字），再把名字加入 `[presets.user].build_types` 才会可见。

**新增编译器** → 需要四处对齐：

1. `template/CMakePresets.json`：加 `<comp>-base`（编译器变量、toolset、`condition`）。
2. `template/CMakeUserPresets.json`：加 `<comp>-<arch>-local` + 各构建类型 configure/build/test 预设。
3. `generate.py`：`ALL_COMPILERS` 登记名字（校验用）、`COMPILER_KEYWORDS` 加关键字（预设名 → 编译器，注意 `clang-cl` 这类更具体的关键字要排在前面）、`COMPILER_CHECKS` 注册检测函数、`HOST_COMPILERS` 标注适用平台；如需新环境变量，改 `required_env_vars()`。

**新增 CMake 生成器** → 把名字加进 `generate.py` 的 `KNOWN_GENERATORS`。

**接入三方库** → 编辑生成的 `src/Dependencies.cmake`，或 `template/src/Dependencies.cmake` 使其对后续工程默认生效；vcpkg 相关在 `cmake/VcpkgConfig.cmake`。

## 已知限制

- **模板没有现成测试用例**：`template/` 不含 `add_test()`。即便 `[project] test_enabled = true`（已注入 `include(CTest)` + `enable_testing()`），在没有注册用例前，`ctest --preset …` 仍是 `No tests were found!!!`（`exit 0`）。
- **Qt / 代码生成需要模块扫描补偿**：`qt_add_executable` 的 autogen（`mocs_compilation.cpp`）等生成源带 `GENERATED` 属性，CMake 会因此默认关闭该 target 的模块扫描，普通源里的 `import std;` 会报 `C2230/C2039`。`cmake/CxxModules.cmake` 已对非生成源显式补开 `CXX_SCAN_FOR_MODULES`（仅此一处，不动探测阶段）。
- **`modules/` 是可选示例**：生成的工程会带一个 `math` 静态库（`math.cppm` + `math.cpp`），但 `add_subdirectory(modules)` 与链接行默认都未启用；两者都打开才会真正构建。该示例已在本机 MSVC / clang-cl 下验证配置与构建通过；GCC / Clang 侧依赖 `cmake/TargetCompilerFlags.cmake` 注入的 `-fmodules-ts` / `-fmodules`，**Linux + gcc 预设未在本机验证**。
- **值里不要写字面 `#{…}`**：`project.toml` 的任意值若包含 `#{…}`，产物残留断言会报错（宁可终止也不静默留下占位符）。
- 重新生成会**删除**输出目录；若其中有你手写的文件请先备份，或改用 `[[project.sub]]` 之外的独立库目录。删除失败（目录被占用/只读）时会直接报错终止，不再继续往旧目录里写文件。

## 仓库结构

```
generate.py          # 生成器
project.toml         # 生成输入
template/            # 工程骨架（占位符 + 预设 + cmake 模块 + vscode 配置）
docs/                # clangd / clang-tidy / vscode / 主题色指南；docs/prompt/（Git Commit 规范、ADR、Prompt 校验）
.agent/skills/       # 供 AI 协作使用的技能库
README.md            # 英文说明
README.zh.md         # 中文说明（本文件）
```
