# Clangd 配置说明

## 目录

- [命令行参数 (VS Code `clangd.arguments`)](#命令行参数-vs-code-clangdarguments)
- [.clangd YAML 配置](#clangd-yaml-配置)
  - [CompileFlags](#compileflags)
  - [Index](#index)
  - [Style](#style)
  - [Diagnostics](#diagnostics)
  - [Completion](#completion)
  - [InlayHints](#inlayhints)
  - [Hover](#hover)
  - [SemanticTokens](#semantictokens)
  - [Documentation](#documentation)
  - [If](#if)

---

## 命令行参数 (VS Code `clangd.arguments`)

在 VS Code 设置中通过 `clangd.arguments` 数组传递：

```json
"clangd.arguments": [
  "--compile-commands-dir=${workspaceFolder}/build",
  "--header-insertion=never",
  "--background-index",
  "--pch-storage=memory",
  "--limit-results=50",
  "--limit-references=1000",
  "-j=4"
]
```

| 参数 | 值 | 说明 |
|---|---|---|
| `--compile-commands-dir` | `<path>` | 指定 `compile_commands.json` 路径。若不指定，clangd 会在源文件父目录中查找 |
| `--query-driver` | `<glob>` | 逗号分隔的通配符列表，白名单中匹配的编译器会被执行以提取系统头文件路径。例如 `/usr/bin/**/clang-*` |
| `--background-index` | - | 在后台索引项目代码并持久化到磁盘，提供跨文件符号信息（跳转、引用等） |
| `--background-index-priority` | `background` / `low` / `normal` | 后台索引线程优先级。`background` 最低，利用空闲 CPU |
| `--clang-tidy` | - | 启用 clang-tidy 诊断 |
| `--completion-style` | `detailed` / `bundled` | 补全粒度。`detailed` 每个语义独立的补全一个条目；`bundled` 同类项（如函数重载）合并显示 |
| `--fallback-style` | `<string>` | 当没有 `.clang-format` 文件时使用的格式化风格 |
| `--function-arg-placeholders` | `0` / `1` | 设置为 `1` 时，补全函数调用时生成参数占位符；`0` 只生成括号 |
| `--header-insertion` | `iwyu` / `never` | 补全时是否自动插入 `#include`。`iwyu` = Include What You Use |
| `--header-insertion-decorators` | - | 在补全标签前显示圆点或空格，指示是否会插入头文件 |
| `--import-insertions` | - | 头文件插入启用时，Objective-C 代码中自动插入 `#import` |
| `--limit-references` | `<int>` | 返回引用结果数量上限，`0` 表示无限制（默认 1000） |
| `--limit-results` | `<int>` | 返回补全结果数量上限，`0` 表示无限制（默认 100） |
| `--rename-file-limit` | `<int>` | 符号重命名影响文件数量上限，`0` 表示无限制（默认 50） |
| `--check` | `[<filename>]` | 隔离解析单个文件而非作为语言服务器运行，用于排查崩溃或配置问题 |
| `--enable-config` | - | 启用从 `.clangd` YAML 文件读取项目和用户配置 |
| `-j` | `<uint>` | clangd 使用的异步工作线程数，后台索引也使用此数量 |
| `--pch-storage` | `disk` / `memory` | PCH（预编译头）存储方式。`memory` 提高性能但增加内存占用 |
| `--log` | `error` / `info` / `verbose` | 写入 stderr 的日志详细程度 |
| `--offset-encoding` | `utf-8` / `utf-16` / `utf-32` | 强制字符偏移编码方式，绕过客户端能力协商 |
| `--path-mappings` | `<client>=<server>,...` | 远程编辑时客户端路径到服务器路径的映射。逗号分隔的 `<client_path>=<server_path>` 对 |
| `--pretty` | - | 美化 JSON 输出 |
| `--all-scopes-completion` | - | 补全时包含不可见作用域（如 namespace）中的索引符号，会自动插入作用域限定符 |
| `--experimental-modules-support` | - | 实验性标准 C++ 模块支持 |

---

## .clangd YAML 配置

除了命令行参数，可以通过项目根目录的 `.clangd` 文件（YAML 格式）或用户级配置文件进行细粒度配置。

- **项目配置**：源文件所在目录或其父目录中的 `.clangd` 文件，应纳入版本控制
- **用户配置**：`%LocalAppData%\clangd\config.yaml`（Windows），作用于所有项目
- 用户配置优先级 > 内层项目配置 > 外层项目配置
- 修改后立即生效，无需重启

### CompileFlags

控制源文件的解析方式。

```yaml
CompileFlags:
  Add: [-xc++, -std=c++23, -Wall]
  Remove: [-W*]
  CompilationDatabase: build/
  Compiler: clang++
  BuiltinHeaders: Clangd
```

| 字段 | 值 | 说明 |
|---|---|---|
| `Add` | `[<flag>, ...]` | 追加到编译命令的标志列表 |
| `Remove` | `[<flag>, ...]` | 从编译命令中移除的标志。若为 clang 已知标志（如 `-I`），会同时移除其参数；以 `*` 结尾时按前缀匹配移除 |
| `CompilationDatabase` | `<path>` / `Ancestors` / `None` | 搜索 `compile_commands.json` 的目录。默认 `Ancestors`（搜索所有父目录），`None` 禁用编译数据库 |
| `Compiler` | `<string>` | 替换编译命令中的可执行文件名，影响标志解析方式（clang vs clang-cl）、目标推断等 |
| `BuiltinHeaders` | `Clangd` / `QueryDriver` | `Clangd` 使用 clangd 内置头文件；`QueryDriver` 从编译器提取系统头文件 |

### Index

控制 clangd 对当前文件之外代码的理解。

```yaml
Index:
  Background: Build
  StandardLibrary: true
  External:
    File: /path/to/index.idx
    Server: my.index.server.com:50051
    MountPoint: /project/root
```

| 字段 | 值 | 说明 |
|---|---|---|
| `Background` | `Build` / `Skip` | 是否在后台构建项目索引。`Skip` 禁用后台索引 |
| `StandardLibrary` | `true` / `false` | 是否预索引标准库符号（即使空文件也能补全标准库符号） |
| `External.File` | `<path>` | 使用 `clangd-indexer` 生成的磁盘索引文件 |
| `External.Server` | `<host>:<port>` | 远程索引服务器地址 |
| `External.MountPoint` | `<path>` | 索引的源文件根目录，用于处理相对路径转换。声明外部索引后会隐式禁用后台索引 |

### Style

描述代码库风格，影响重构和补全行为。

```yaml
Style:
  FullyQualifiedNamespaces: [llvm, boost]
  QuotedHeaders: "src/.*"
  AngledHeaders: ["path/sdk/.*", "third-party/.*"]
```

| 字段 | 值 | 说明 |
|---|---|---|
| `FullyQualifiedNamespaces` | `[<ns>, ...]` | 这些 namespace 必须始终全限定，不允许 `using` 声明，影响 AddUsing 重构的可用性 |
| `QuotedHeaders` | `[<regex>, ...]` | 匹配的路径使用 `""` 引入头文件 |
| `AngledHeaders` | `[<regex>, ...]` | 匹配的路径使用 `<>` 引入头文件 |

### Diagnostics

控制诊断行为。

```yaml
Diagnostics:
  Suppress: [unused-parameter, -Wunused-result]
  UnusedIncludes: Strict
  MissingIncludes: Strict
  ClangTidy:
    Add: [bugprone-*, performance-*]
    Remove: [modernize-use-trailing-return-type]
    CheckOptions:
      readability-identifier-naming.VariableCase: camelBack
    FastCheckFilter: Strict
  Includes:
    IgnoreHeader: ["*/generated/*"]
    AnalyzeAngledIncludes: false
```

| 字段 | 值 | 说明 |
|---|---|---|
| `Suppress` | `[*]` / `[<code>, ...]` | 屏蔽指定诊断。`*` 禁用所有诊断；可填 clangd 诊断码、clang 内部诊断码、警告类别、clang-tidy 检查名 |
| `UnusedIncludes` | `None` / `Strict` | Include Cleaner 未使用头文件检测（clangd 17+ 默认 `Strict`） |
| `MissingIncludes` | `None` / `Strict` | Include Cleaner 缺失头文件检测（默认 `None`） |
| `ClangTidy.Add` | `[<check>, ...]` | 启用的 clang-tidy 检查，支持通配符 |
| `ClangTidy.Remove` | `[<check>, ...]` | 禁用的 clang-tidy 检查，优先级高于 Add |
| `ClangTidy.CheckOptions` | `<key>: <value>` | clang-tidy 检查的选项配置 |
| `ClangTidy.FastCheckFilter` | `Strict` / `Loose` / `None` | 是否运行可能拖慢 clangd 的 tidy 检查。`Strict` 仅运行已知快速的检查 |
| `Includes.IgnoreHeader` | `[<regex>, ...]` | 正则匹配的头文件不会被 Include Cleaner 产生诊断 |
| `Includes.AnalyzeAngledIncludes` | `true` / `false` | 是否检测非标准库的尖括号包含（默认禁用，避免伞状头文件误报） |

### Completion

配置代码补全行为。

```yaml
Completion:
  AllScopes: Yes
  ArgumentLists: FullPlaceholders
  HeaderInsertion: IWYU
  CodePatterns: All
  MacroFilter: ExactPrefix
```

| 字段 | 值 | 说明 |
|---|---|---|
| `AllScopes` | `Yes` / `No` | 是否补全不可见作用域中的符号，自动插入 namespace 前缀（默认 `Yes`） |
| `ArgumentLists` | `None` / `OpenDelimiter` / `Delimiters` / `FullPlaceholders` | 补全函数调用时参数列表插入方式。`None` 只补全函数名；`FullPlaceholders` 生成 `(int arg)` 占位符 |
| `HeaderInsertion` | `IWYU` / `Never` | 补全时自动插入 `#include`。`IWYU` = Include What You Use |
| `CodePatterns` | `All` / `None` | 是否建议代码片段和模式 |
| `MacroFilter` | `ExactPrefix` / `FuzzyMatch` | 宏补全匹配方式。`ExactPrefix` 精确前缀匹配；`FuzzyMatch` 模糊匹配（以下划线开头/结尾的宏仍排除） |

### InlayHints

控制内联提示（inline hints）行为。

```yaml
InlayHints:
  Enabled: true
  ParameterNames: true
  DeducedTypes: true
  Designators: true
  BlockEnd: false
  DefaultArguments: false
  TypeNameLimit: 24
```

| 字段 | 值 | 说明 |
|---|---|---|
| `Enabled` | `true` / `false` | 内联提示总开关 |
| `ParameterNames` | `true` / `false` | 函数调用处显示参数名提示（如 `foo(` 旁显示 `arg:`） |
| `DeducedTypes` | `true` / `false` | 显示 `auto` 推断类型 |
| `Designators` | `true` / `false` | 聚合初始化中显示指示符（如 `{.x= 1}`） |
| `BlockEnd` | `true` / `false` | 在闭合括号后显示块名（如 `} // foo`） |
| `DefaultArguments` | `true` / `false` | 显示默认参数值提示 |
| `TypeNameLimit` | `<int>` | 类型提示字符数上限，超过不显示。`0` 无限制 |

### Hover

控制悬停卡片内容。

```yaml
Hover:
  ShowAKA: false
  MacroContentsLimit: 2048
```

| 字段 | 值 | 说明 |
|---|---|---|
| `ShowAKA` | `true` / `false` | 是否显示类型的脱糖形式，如 `vector<int>::value_type (aka int)` |
| `MacroContentsLimit` | `<int>` | 宏展开悬停显示的字符数上限。`0` 无限制（默认 2048） |

### SemanticTokens

控制语义高亮。

```yaml
SemanticTokens:
  DisabledKinds: []
  DisabledModifiers: []
```

| 字段 | 值 | 说明 |
|---|---|---|
| `DisabledKinds` | `[<kind>, ...]` | 不发送给客户端的语义标记类型（如 `namespace`、`variable` 等） |
| `DisabledModifiers` | `[<modifier>, ...]` | 不发送给客户端的语义标记修饰符（如 `deprecated`、`virtual` 等） |

### Documentation

控制文档注释格式。

```yaml
Documentation:
  CommentFormat: Plaintext
```

| 字段 | 值 | 说明 |
|---|---|---|
| `CommentFormat` | `Plaintext` / `Markdown` / `Doxygen` | 文档注释格式。`Doxygen` 在 Markdown 基础上额外解析 doxygen 命令，转换函数参数/返回值文档 |

### If

条件生效，限制配置片段的适用范围。

```yaml
If:
  PathMatch: .*\.h
  PathExclude: include/llvm-c/.*
CompileFlags:
  Add: [-DHEADER_BUILD]
---
If:
  PathMatch: [src/.*\.cpp, tests/.*\.cpp]
Index:
  Background: Build
```

| 字段 | 值 | 说明 |
|---|---|---|
| `PathMatch` | `<regex>` / `[<regex>, ...]` | 文件路径必须完全匹配正则（多个值之间是 OR 关系） |
| `PathExclude` | `<regex>` / `[<regex>, ...]` | 文件路径必须不匹配正则（多个值之间是 OR 关系） |

路径规则：
- 若片段来自项目目录，路径为相对路径
- 若片段来自全局配置（用户配置），路径为绝对路径
- 路径始终使用正斜杠（Unix 风格）

---

## 配置加载与优先级

1. clangd 搜索源文件所有父目录中的 `.clangd` 文件
2. 加载用户配置（`%LocalAppData%\clangd\config.yaml`）
3. 多个片段通过 `---` 分隔，每个片段可以有不同的 `If` 条件
4. 优先级：用户配置 > 内层项目配置 > 外层项目配置
5. 合理情况下配置会合并，冲突时高优先级胜出
