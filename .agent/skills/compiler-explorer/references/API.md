# Compiler Explorer API 参考（Skill 内部用）

> 依据官方文档 (https://github.com/compiler-explorer/compiler-explorer/blob/main/docs/API.md)
> 与 `https://compiler-explorer.com` Solo 实例实测结果整理。
> 更新语言/编译器索引用 `scripts/ce-enum.ps1`；构造请求用 `scripts/ce-build.ps1`。

## 1. 端点和头

所有端点都在 `{BaseUrl}/api/*`。**想要 JSON 响应必须带 `Accept: application/json` 头**，否则返回纯文本/HTML 式内容。

| 端点 | 方法 | 用途 |
|---|---|---|
| `/api/languages` | GET | 语言列表（id/name/extensions） |
| `/api/compilers/<lang>` | GET | 该语言的编译器/解释器列表 |
| `/api/libraries/<lang>` | GET | 可用的库及其版本 id |
| `/api/tools/<lang>` | GET | 可用工具（clang-tidy 等） |
| `/api/compiler/<id>/compile` | POST | 编译（+可选执行） |
| `/api/compiler/<id>/cmake` | POST | CMake 项目构建 |
| `/api/version` | GET | 实例版本 |

BaseUrl 默认 `https://compiler-explorer.com`。注意：Solo 实例只认它自己列表里的编译器 ID
（如 `g122`、`python312`），用不在列表里的 ID 会 404 `Not Found`。**任何 404 先查
`references/<lang>.md` 确认 ID 存在**。

## 2. 编译请求体 (POST /api/compiler/{id}/compile)

```json
{
  "source": "<源代码字符串>",
  "options": {
    "userArguments": "-O2 -std=c++20 -Wall",
    "compilerOptions": {
      "executorRequest": true,
      "skipAsm": false,
      "overrides": []
    },
    "filters": {
      "binary": false, "binaryObject": false, "commentOnly": true,
      "demangle": true, "directives": false, "execute": false,
      "intel": true, "labels": false, "libraryCode": false,
      "trim": false, "debugCalls": false
    },
    "executeParameters": { "args": ["a","b"], "stdin": "输入文本", "runtimeTools": [] },
    "tools": [],
    "libraries": []
  },
  "lang": "c++",
  "allowStoreCodeDebug": true,
  "bypassCache": 0,
  "files": [ { "filename": "a.h", "contents": "#define X 42" } ]
}
```

- `source`：主源码。多文件编译时附加文件放 `files[]`（文件名+内容）。
- `userArguments`：传给编译器的命令行参数（本技能中“编译器参数设置”就是它）。
- `compilerOptions.executorRequest`：是否请求**执行**阶段。要运行程序必须 `true`。
- `filters.execute`：执行开关（常与 executorRequest 同开）。
- `filters.binary`：请求**汇编输出**。注意：请求执行时（execute=true）响应不含 asm 数组，汇编与执行二选一，或分两次请求。
- `filters.labels/directives/commentOnly/trim/intel`：控制汇编形态（label 行/伪指令/注释/裁剪/语法）。
- `executeParameters.args/stdin`：执行时程序入参和 stdin。
- `libraries`：`[{"id":"fmt","version":"400"}]`，id/version 用 `/api/libraries/<lang>` 查。
- `tools`：`[{"id":"clangtidytrunk","args":"-checks=*"}]`。
- `bypassCache`：0 不绕过 / 1 绕过编译缓存 / 2 绕过执行缓存。
- `lang`：语言 id（可选，建议带上，注解/着色用）。

## 3. 响应 JSON —— 两种形态

### 形态 A：纯编译（execute=false，响应含汇编）

```json
{
  "code": 0,
  "asm": [ { "text": "main:\n ...", "source": {"file": null, "line": 1} } ],
  "asmSize": 512,
  "stdout": [ {"text": "..."} ],
  "stderr": [ {"text": "..."} ],
  "optOutput": { "...": "优化报告(如有)" },
  "tools": [],
  "timedOut": false,
  "truncated": false,
  "okToCache": true,
  "instructionSet": "amd64",
  "compilationOptions": { "...": "实际编译器选项" }
}
```

- `code`：编译器进程退出码（0 成功；非 0 编译失败）。
- `stderr[]`：编译诊断（错误/警告），逐行 `{"text":...}`。
- `asm[]`：汇编行（`text` 带 ANSI 代码，`source.line` 关联源码行）。
- 拼接文本用 `($obj.stdout | ForEach-Object text) -join ''`。

### 形态 B：编译+执行（executorRequest=true + filters.execute=true）

```json
{
  "code": 3,
  "stdout": [ {"text": "运行 stdout"} ],
  "stderr": [ {"text": "运行 stderr"} ],
  "didExecute": true,
  "execTime": 28,
  "processExecutionResultTime": 0.02,
  "timedOut": false,
  "buildResult": {
    "code": 0,
    "stdout": [], "stderr": [ {"text": "编译诊断"} ],
    "execTime": 1260,
    "inputFilename": "/nosym/tmp/.../example.cpp",
    "instructionSet": "amd64"
  }
}
```

- 根级 `code/stdout/stderr` = **执行**结果；嵌套 `buildResult.code/stdout/stderr` = **编译**结果。
- 判断成败顺序：先看 `buildResult.code`（编译），再看 `didExecute` 与根级 `code`（执行）。
- 声明式语言（Python/Ruby/JS 等解释器）同样走此形态，`buildResult` 即解释器加载阶段。

## 4. 常见故障速查

| 现象 | 原因与处理 |
|---|---|
| 404 Not Found | 编译器 ID 不在该实例列表 → 查 `references/<lang>.md` 换 ID |
| 响应是 HTML/文本 | 缺 `Accept: application/json` 头 |
| asm 为空但 binary=true | 同时开了 execute → 汇编与执行分开请求 |
| timedOut=true | 编译/执行超时 → 减小编译负载或重试 |
| code非0 + stderr | 编译错误 → 按 stderr 定位源码行修复后重发（下一轮） |
| stdout 有 ANSI 转义 | 客户端显示需去色，文件记录保留原始文本 |

## 5. 与脚本的对应关系

| 需求 | 脚本调用 |
|---|---|
| 编译（含/不含汇编） | `ce-build.ps1 -Compiler <id> -SourceFile f.cpp -UserArguments ... [-Asm]` |
| 编译+运行 | 追加 `-Execute [-Stdin ...] [-ExecArg ...]` |
| 多文件 | `-Files '[{"filename":"a.h","contents":"..."}]'` |
| 引库/工具 | `-Library '[...]'` / `-Tool '[...]'` |
| 更新参考索引 | `ce-enum.ps1` |