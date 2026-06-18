# Clang-Tidy 配置说明

## 目录

- [简介](#简介)
- [命令行用法](#命令行用法)
- [命令行参数详解](#命令行参数详解)
- [.clang-tidy 配置文件](#clang-tidy-配置文件)
- [检查项分类](#检查项分类)
- [与 CMake 集成](#与-cmake-集成)
- [与 VS Code 集成](#与-vs-code-集成)
- [在 clangd 中启用 clang-tidy](#在-clangd-中启用-clang-tidy)
- [自动化运行](#自动化运行)
- [抑制诊断](#抑制诊断)

---

## 简介

**clang-tidy** 是一个基于 clang 的 C++ 静态分析工具，提供可扩展框架，用于诊断和自动修复典型的编程错误：风格违规、接口误用、可通过静态分析推导的 bug。

特点：

- 模块化设计，支持自定义检查
- 支持自动修复（`--fix`）
- 可与 CMake 等构建系统集成
- 可作为 clang-tidy 检查运行（在 clangd 中集成）
- 同时支持 Clang Static Analyzer 检查

---

## 命令行用法

```bash
# 基本用法：分析单个文件
clang-tidy test.cpp -- -Imy_project/include -DMY_DEFINES

# 使用 compile_commands.json
clang-tidy -p build/ test.cpp

# 启用特定检查
clang-tidy -p build/ --checks="-*,bugprone-*,readability-*" test.cpp

# 自动修复
clang-tidy -p build/ --fix test.cpp

# 使用参数文件
clang-tidy @parameters_file
```

## 命令行参数详解

### 基本选项

| 参数 | 说明 |
|---|---|
| `--checks=<string>` | 逗号分隔的通配符列表，带 `-` 前缀表示禁用。按顺序处理。例如 `-*,bugprone-*` 禁用所有、启用 bugprone 组 |
| `--config=<string>` | 以 YAML/JSON 格式指定配置。如 `-config="{Checks: '*', CheckOptions: {x: y}}"`。值为空时自动搜索 `.clang-tidy` |
| `--config-file=<path>` | 指定 `.clang-tidy` 或自定义配置文件的路径。与 `--config` 互斥 |
| `--dump-config` | 将当前配置以 YAML 格式输出到 stdout。结合 `-checks=*` 可输出所有检查的配置 |
| `--explain-config` | 解释每个检查是在哪里启用的（二进制、命令行或配置文件） |
| `--list-checks` | 列出所有启用的检查。使用 `-checks=*` 可列出所有可用检查 |
| `--verify-config` | 验证配置文件中的检查和选项是否有效，不实际运行检查 |

### 编译选项

| 参数 | 说明 |
|---|---|
| `-p <string>` | 构建路径，用于读取 `compile_commands.json`。例如 CMake 构建目录 |
| `--extra-arg=<string>` | 追加额外的编译参数 |
| `--extra-arg-before=<string>` | 在编译参数前插入额外参数 |
| `--removed-arg=<string>` | 从编译命令中移除指定参数。在 `--extra-arg` 之前应用 |

### 诊断过滤选项

| 参数 | 说明 |
|---|---|
| `--header-filter=<regex>` | 输出诊断的头文件正则匹配。默认 `.*`（所有非系统头文件）。主文件的诊断始终显示 |
| `--exclude-header-filter=<regex>` | 排除诊断的头文件正则，须与 `--header-filter` 一起使用 |
| `--line-filter=<string>` | JSON 格式的文件和行范围过滤。例如 `[{"name":"file1.cpp","lines":[[1,3],[5,7]]}]` |
| `--system-headers` | 显示系统头文件中的错误 |
| `--quiet` | 安静模式，不打印统计信息 |

### 修复选项

| 参数 | 说明 |
|---|---|
| `--fix` | 应用建议的修复。如果存在编译错误则中止 |
| `--fix-errors` | 即使存在编译错误也应用修复 |
| `--fix-notes` | 如果警告无修复但关联的 note 提供了修复，则应用。隐含 `--fix` |
| `--format-style=<string>` | 修复后格式化代码的风格。可选 `none` / `file` / `{json}` / `llvm` / `google` / `webkit` / `mozilla` |
| `--export-fixes=<filename>` | 将建议的修复导出到 YAML 文件，可用 `clang-apply-replacements` 应用 |

### 其他选项

| 参数 | 说明 |
|---|---|
| `--load=<plugin>` | 加载指定插件 |
| `--enable-check-profile` | 启用每个检查的计时分析，输出到 stderr |
| `--store-check-profile=<prefix>` | 将分析结果存储为 JSON 文件 |
| `--enable-module-headers-parsing` | （实验性）启用 C++20 模块头文件解析 |
| `--experimental-custom-checks` | 启用基于 clang-query 的自定义检查 |
| `--warnings-as-errors=<string>` | 将警告升级为错误，格式同 `--checks` |
| `--use-color` | 使用颜色输出诊断 |
| `--allow-no-checks` | 允许空的启用的检查列表 |
| `--vfsoverlay=<filename>` | 虚拟文件系统覆盖 |

---

## .clang-tidy 配置文件

clang-tidy 会为每个源文件在其父目录中搜索 `.clang-tidy` 文件，格式为 YAML。

### 配置字段

```yaml
Checks: '-*,bugprone-*,readability-*,performance-*'
WarningsAsErrors: 'bugprone-*'
HeaderFileExtensions: ['', 'h', 'hh', 'hpp', 'hxx']
ImplementationFileExtensions: ['c', 'cc', 'cpp', 'cxx']
HeaderFilterRegex: '.*'
FormatStyle: none
InheritParentConfig: true
User: user
SystemHeaders: false
UseColor: true
CustomChecks: []
ExtraArgs: []
ExtraArgsBefore: []
RemovedArgs: []
ExcludeHeaderFilterRegex: ''
CheckOptions:
  readability-identifier-naming.ClassCase: CamelCase
  readability-identifier-naming.VariableCase: camelBack
  readability-identifier-naming.FunctionCase: camelBack
  readability-identifier-naming.MemberCase: camelBack
  readability-identifier-naming.PrivateMemberSuffix: _
  bugprone-easily-swappable-parameters.MinimumLength: 2
```

| 字段 | 默认值 | 说明 |
|---|---|---|
| `Checks` | `''` | 同上 `--checks`。支持列表格式而非字符串 |
| `WarningsAsErrors` | `''` | 同上 `--warnings-as-errors` |
| `HeaderFileExtensions` | `['', 'h','hh','hpp','hxx']` | 视为头文件的扩展名列表 |
| `ImplementationFileExtensions` | `['c','cc','cpp','cxx']` | 视为实现文件的扩展名列表 |
| `HeaderFilterRegex` | `'.*'` | 同上 `--header-filter` |
| `ExcludeHeaderFilterRegex` | `''` | 同上 `--exclude-header-filter` |
| `FormatStyle` | `none` | 同上 `--format-style` |
| `InheritParentConfig` | `true` | 如果为 `true`，会继承父目录 `.clang-tidy` 的配置，当前配置覆盖父配置 |
| `User` | `user` | 用户名或邮箱，用于 TODO() 注释中的名字 |
| `SystemHeaders` | `false` | 同上 `--system-headers` |
| `UseColor` | 自动检测 | 同上 `--use-color` |
| `CustomChecks` | `[]` | 基于 clang-query 语法的用户自定义检查数组 |
| `ExtraArgs` | `[]` | 同上 `--extra-arg` |
| `ExtraArgsBefore` | `[]` | 同上 `--extra-arg-before` |
| `RemovedArgs` | `[]` | 同上 `--removed-arg` |
| `CheckOptions` | `{}` | 各检查的专用选项，格式为 `check-name.OptionName: value` |

### 配置加载优先级

1. 命令行参数 > `.clang-tidy` 配置文件
2. 离源文件最近的 `.clang-tidy` 优先级最高
3. `InheritParentConfig: true` 时继承父目录配置

---

## 检查项分类

clang-tidy 所有检查按前缀分为以下类别：

| 前缀 | 说明 |
|---|---|
| `abseil-*` | Abseil 库相关检查 |
| `altera-*` | FPGA OpenCL 编程相关 |
| `android-*` | Android 相关 |
| `boost-*` | Boost 库相关 |
| `bugprone-*` | 易错代码构造 |
| `cert-*` | CERT 安全编码规范 |
| `clang-analyzer-*` | Clang Static Analyzer 检查 |
| `concurrency-*` | 并发编程相关（线程、纤程、协程） |
| `cppcoreguidelines-*` | C++ Core Guidelines |
| `darwin-*` | Darwin 编码规范 |
| `fuchsia-*` | Fuchsia 编码规范 |
| `google-*` | Google 编码规范 |
| `linuxkernel-*` | Linux 内核编码规范 |
| `llvm-*` | LLVM 编码规范 |
| `llvmlibc-*` | LLVM-libc 编码标准 |
| `misc-*` | 无法归类的杂项检查 |
| `modernize-*` | 使用现代 C++ 特性（C++11 以上） |
| `mpi-*` | MPI 消息传递接口 |
| `objc-*` | Objective-C 编码规范 |
| `openmp-*` | OpenMP API 相关 |
| `performance-*` | 性能相关问题 |
| `portability-*` | 可移植性问题 |
| `readability-*` | 可读性问题 |
| `zircon-*` | Zircon 内核编码规范 |
| `clang-diagnostic-*` | Clang 编译器警告（通过 `-W` 选项控制） |

此外，clang-tidy 还可以启用 clang 自身的诊断，其检查名称为 `clang-diagnostic-<warning-option>`，如 `clang-diagnostic-literal-conversion`。`clang-diagnostic-error` 不可禁用（编译必须通过才能分析）。

### 推荐常用检查组合

```yaml
# 新手入门推荐
Checks: '-*,bugprone-*,performance-*,readability-*,modernize-*'

# 完整项目风格检查
Checks: '-*,bugprone-*,performance-*,readability-*,modernize-*,cppcoreguidelines-*,misc-*'

# 最严格模式（含 Clang Static Analyzer）
Checks: '-*,bugprone-*,performance-*,readability-*,modernize-*,cppcoreguidelines-*,misc-*,clang-analyzer-*'

# Google 风格
Checks: '-*,google-*,readability-*'

# 仅检查严重问题
Checks: '-*,bugprone-*,clang-analyzer-*'
```

---

## 与 CMake 集成

### 1. 生成 compile_commands.json

```cmake
# CMakeLists.txt
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
```

或在 VS Code 中设置：

```json
"cmake.exportCompileCommandsFile": true
```

### 2. 直接使用

```bash
# 分析单个文件
clang-tidy -p out/build/clang_cl_x64_debug src/main.cpp

# 分析整个项目
run-clang-tidy.py -p out/build/clang_cl_x64_debug

# 使用额外参数
clang-tidy -p build/ --checks="-*,modernize-*" --fix src/*.cpp -- -std=c++23
```

### 3. CMake 中集成 clang-tidy（自动运行）

```cmake
# 方法一：设置 CMAKE_CXX_CLANG_TIDY
set(CMAKE_CXX_CLANG_TIDY
    clang-tidy
    -checks=-*,bugprone-*,performance-*
    -warnings-as-errors=*)

# 方法二：带配置文件的版本
set(CMAKE_CXX_CLANG_TIDY
    clang-tidy
    --config-file=${CMAKE_SOURCE_DIR}/.clang-tidy)
```

设置后每次编译都会自动运行 clang-tidy。

### 4. CMake 自定义目标

```cmake
# 添加一个单独运行 clang-tidy 的目标
add_custom_target(tidy
    COMMAND run-clang-tidy.py -p ${CMAKE_BINARY_DIR}
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Running clang-tidy on all files"
)

# 添加自动修复目标
add_custom_target(tidy-fix
    COMMAND run-clang-tidy.py -p ${CMAKE_BINARY_DIR} -fix
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Running clang-tidy with auto-fix on all files"
)
```

---

## 与 VS Code 集成

### VS Code 中直接使用

推荐安装 VS Code 扩展 **clang-tidy**：

```json
// settings.json
"clang-tidy.enabled": true,
"clang-tidy.checks": [
  "bugprone-*",
  "performance-*",
  "readability-*"
],
"clang-tidy.fixOnSave": false,
"clang-tidy.headerFilter": ".*",
"clang-tidy.lintOnSave": true,
"clang-tidy.compilerArgs": ["-std=c++23"]
```

也可通过任务系统配置：

```json
// .vscode/tasks.json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "clang-tidy",
      "type": "shell",
      "command": "clang-tidy",
      "args": [
        "-p=${workspaceFolder}/out/build",
        "-checks=-*,bugprone-*,performance-*",
        "${file}"
      ],
      "problemMatcher": ["$clangTidy"],
      "group": "build"
    }
  ]
}
```

---

## 在 clangd 中启用 clang-tidy

clangd 可以直接运行 clang-tidy 检查，无需单独配置 clang-tidy。

### 命令行方式

在 VS Code `clangd.arguments` 中添加：

```json
"clangd.arguments": [
  "--clang-tidy",
  "--clang-tidy-checks=-*,bugprone-*,performance-*,readability-*"
]
```

### .clangd YAML 方式

```yaml
Diagnostics:
  ClangTidy:
    Add: [bugprone-*, performance-*, readability-*]
    Remove: [modernize-use-trailing-return-type]
    CheckOptions:
      readability-identifier-naming.ClassCase: CamelCase
      readability-identifier-naming.VariableCase: camelBack
      readability-identifier-naming.FunctionCase: camelBack
      readability-identifier-naming.MemberCase: camelBack
      readability-identifier-naming.PrivateMemberSuffix: _
      readability-function-size.LineThreshold: 100
      bugprone-easily-swappable-parameters.MinimumLength: 2
    FastCheckFilter: Strict
```

| 字段 | 值 | 说明 |
|---|---|---|
| `Add` | `[<check>, ...]` | 启用的检查列表，支持通配符 |
| `Remove` | `[<check>, ...]` | 禁用的检查列表，优先级高于 Add |
| `CheckOptions` | `<key>: <value>` | 检查专用选项 |
| `FastCheckFilter` | `Strict` / `Loose` / `None` | `Strict` 只运行已知快速的检查；`Loose` 排除已知慢的；`None` 全部运行 |

clangd 也会读取项目中的 `.clang-tidy` 配置文件，且 `.clangd` 中 ClangTidy 配置的优先级更高。

---

## 自动化运行

### run-clang-tidy.py（并行）

clang-tidy 自带的 Python 脚本，支持并行分析和多种选项：

```bash
# 并行分析所有文件
run-clang-tidy.py -p=build/

# 指定检查并修复
run-clang-tidy.py -p=build/ -fix -checks="-*,readability-*"

# 指定 CPU 核心数
run-clang-tidy.py -p=build/ -j 4

# 过滤头文件
run-clang-tidy.py -p=build/ -header-filter=src/ src/
```

### clang-tidy-diff.py（仅分析 diff）

只分析变更行，适合 Code Review 和 CI：

```bash
# 分析工作区变更
git diff -U0 --no-color HEAD | clang-tidy-diff.py -p1

# 分析并修复
git diff -U0 --no-color HEAD^ | clang-tidy-diff.py -p1 -fix -checks="-*,readability-*"

# 分析暂存区变更
git diff -U0 --no-color --cached | clang-tidy-diff.py -p1

# 分析补丁文件
clang-tidy-diff.py -p1 < changes.patch
```

> **注意**：clang-tidy-diff.py 只报告变更行上的诊断。某些问题（如函数超长）可能在非变更行上报告而被过滤掉。

### CI 集成示例

```yaml
# GitHub Actions
- name: Run clang-tidy
  run: |
    cmake -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    run-clang-tidy.py -p build/ -j $(nproc)
```

---

## 抑制诊断

### NOLINT 系列注释

```cpp
class Foo {
  // 抑制当前行的所有诊断
  Foo(int param); // NOLINT

  // 带原因说明
  Foo(char param); // NOLINT: Allow implicit conversion from 'char', because <reason>

  // 仅抑制指定检查
  Foo(double param); // NOLINT(google-explicit-constructor, google-runtime-int)

  // 通配符抑制
  Foo(bool param); // NOLINT(google-*)
  int array[10]; // NOLINT(*-avoid-c-arrays)

  // 抑制下一行的所有诊断
  // NOLINTNEXTLINE(google-explicit-constructor)
  Foo(bool param);

  // 抑制多行（BEGIN/END 配对）
  // NOLINTBEGIN(bugprone-*)
  Foo(short param);
  Foo(long param);
  // NOLINTEND(bugprone-*)
};
```

### 语法规则

```
NOLINT[ | NOLINTNEXTLINE | NOLINTBEGIN | NOLINTEND][(check-name-list)]
```

- `NOLINT` 作用于**同一行**
- `NOLINTNEXTLINE` 作用于**下一行**
- `NOLINTBEGIN` / `NOLINTEND` 作用于**两者之间的所有行（含两端）**
- `NOLINT` 与 `(` 之间不能有空格
- 括号内支持通配符（如 `google-*`、`*-avoid-c-arrays`）
- `NOLINTBEGIN` 必须与 `NOLINTEND` 配对，且参数必须匹配
- 不匹配的 `NOLINTBEGIN`/`NOLINTEND` 会产生 `clang-tidy-nolint` 错误

### 配置文件中禁用检查

```yaml
# .clang-tidy
Checks: '-*,bugprone-*,-bugprone-easily-swappable-parameters'
```

### 源代码中使用 `__attribute__` 或 `[[gsl::suppress]]`

```cpp
// GSL 风格抑制
[[gsl::suppress("readability-magic-numbers")]]
int calculate() {
  return 42;
}
```

---

## clang-tidy 与 clangd 的关系

| | clangd | clang-tidy |
|---|---|---|
| 定位 | 语言服务器（IDE 功能） | 静态分析工具 |
| 运行方式 | 后台持续运行 | 按需运行或 CI 中 |
| clang-tidy 检查 | 可选启用（通过配置） | 核心功能 |
| 自动修复 | 不支持 | 支持（`--fix`） |
| 性能 | 受 `FastCheckFilter` 控制 | 所有检查 |
| 使用场景 | 编码时实时提示 | 代码审查、CI 检查、批量修复 |

推荐组合使用：clangd 开启少量快速 clang-tidy 检查用于实时提示，CI 中使用完整的 clang-tidy 进行深度分析。
