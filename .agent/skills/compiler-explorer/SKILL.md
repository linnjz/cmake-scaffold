---
name: compiler-explorer
description: 通过 Compiler Explorer (godbolt) 在线 API 在远程环境选择语言/编译器/解释器版本与参数，编译、运行、取汇编，返回 JSON 结果并迭代修复到功能完成。Use when 用户指名使用 compiler-explorer/godbolt CE 进行开发或功能测试、功能验证、跨平台/跨编译器版本对比测试、需要本机没有的语言/编译器/平台环境（如 ARM、AVR、新语言版本）时。
---

# Compiler Explorer (CE) 远程构建/运行

## 定位（边界）

本技能只提供**远程环境**能力：定语言/编译器/版本/平台/参数 → 构造请求 → 提交构建运行 → 解析 JSON → 反馈下一轮。
需求分析、方案设计、测试用例（单例/模糊/边界）、报告输出等**规划类工作交给其他 skill**；本技能的产物是"本轮代码 + 本轮结果 + handoff"。

## 触发条件

1. 用户明确点名 compiler-explorer / godbolt / CE；
2. 功能测试、跨平台/跨编译器版本验证，且本机缺少该语言/编译器环境。

## 语言选择优先级

1. 用户明确指定（最高优先）；
2. 当前会话上下文推断（前文提到过的语言/代码片段）；
3. 当前项目推断：扫描 cwd —— 源码扩展名（`.cpp/.rs/.go/.py`...）、构建文件（`CMakeLists.txt`→c++/cmake、`Cargo.toml`→rust、`package.json`→js/ts、`go.mod`→go、`pyproject.toml`→python）；
4. 无法确定 → 询问用户，不要瞎猜。

确定语言后到索引选编译器：

```
references/_LANGUAGES.md        # 97 语言索引表 → 点进对应 <lang>.md
references/<lang>.md            # 该语言编译器/解释器表: ID | 名称 | 版本 | 指令集 | 类型
```

选编译器按三要素：**平台**（指令集列：amd64/arm32/aarch64/avr/6502/dex/mips...）、**版本**（semver 列）、**类型**（gcc/clang/msvc/解释器等）。索引过期时运行 `pwsh scripts/ce-enum.ps1` 重新爬取。

**参数参考**：c/c++/csharp/java/javascript/python/rust/typescript 等语言文件末尾都有
`## 可设置参数（userArguments）参考` 章节（来源为各工具链权威文档），涵盖优化选项、
语言/标准版本、警告诊断、特殊设置与常用组合；选参数时先查该节，未覆盖的语言按该语言惯例。

## 请求撰写与响应获取

请求/响应细节见 [references/API.md](references/API.md)，客户端脚本为 [scripts/ce-build.ps1](scripts/ce-build.ps1)。要点：

- 端点 `POST {base}/api/compiler/<compiler-id>/compile`，**必须带 `Accept: application/json` 头**；base 默认 `https://compiler-explorer.com`。
- 请求体：`source` + `options.userArguments`（编译器参数）+ `filters`（execute 执行 / binary 汇编 / intel / labels / commentOnly...）+ `executeParameters`（stdin/args）+ 可选 `libraries/tools/files`。
- **404 多半是编译器 ID 不存在**，回 `references/<lang>.md` 换 ID。
- 响应两种形态：
  - 纯编译：根级 `code`=编译退出码，`stderr[]`=诊断，`asm[]`=汇编；
  - 编译+执行：根级 `code/stdout/stderr`=执行结果，嵌套 `buildResult.code`=编译结果。
- 成败判定：编译 `buildResult.code` 或根 `code` 非 0 = 编译失败；随后看 `didExecute` 与执行码。

## 任务文件与命名约定

每个任务落在 **当前工作目录** `docs/ce-tasks/<TaskId>/`，`TaskId = yyyyMMdd-HHmmss-<标签>`（如 `docs/ce-tasks/20260811-103022-fib/`）：

| 文件 | 内容 |
|---|---|
| `task.md` | 任务说明：语言、编译器、参数、目标（首轮创建） |
| `rNN-source.<ext>` | 第 NN 轮源码（NN=01,02,...） |
| `rNN-request.json` | 第 NN 轮请求体（可原样回放） |
| `rNN-response.json` | 第 NN 轮原始响应 |
| `rNN-summary.md` | 第 NN 轮解析摘要（编译码/诊断/汇编片段/执行结果） |
| `handoff.md` | 交接文档，每轮覆盖更新 |

直接调用脚本即可自动生成上述文件：

```powershell
pwsh <skill>/scripts/ce-build.ps1 -Compiler g122 -SourceFile main.cpp -UserArguments '-O2 -std=c++20 -Wall' -Execute -Lang c++ -Tag fib -Round 1 -AsmBase docs/ce-tasks
# 下一轮: 同 -TaskId, -Round 2, 改源码后重跑
```

## 迭代工作循环（直到功能完成）

1. 定语言/编译器/参数 → 写源码（或由其他 skill 提供代码）。未指定参数时参考项目原有构建配置或按该语言惯用参数（如 c++: `-std=c++20 -Wall -O2`）。
2. `ce-build.ps1` 提交 → 读 `rNN-summary.md`。
3. 失败 → 按 stderr 诊断修改源码，`-Round +1` 重跑；
4. 通过 → 用户要求的话做**多版本/多平台对比**（换编译器 ID 同 If main 循环），或边界/单例测试（用例由测试类 skill 提供，本技能仅负责换环境执行）。
5. 每轮结束更新 `handoff.md`（脚本自动写），必要时由协作 agent 补“下一轮建议”。

## Handoff 交接

- **每轮**：`handoff.md` 自动更新（编译器/参数/状态 PASS|FAIL/诊断/执行输出/阶段文件位置）。agent 可在回复中给一行状态摘要：`CE r03 g122:-O2 c++20 → PASS，输出 "fib(10)=55"，下一步测 arm linux 交叉编译`。
- **任务完成**：在 `handoff.md` 顶部标注 `[DONE]` 并写最终结论（编译器+参数+验证矩阵+产物路径）；回复用户时汇总语言/编译器/参数/结果/文件位置。
- **任务中断**（换会话/换 agent）：读完 `handoff.md` 即可无痛续跑（含文件、参数、轮次）。

## 注意事项

- 本实例编译器 ID 不含 `g++` 这类别名；一律用索引里的 ID。
- 汇编与执行不同时返回：要汇编就分开请求或不要开 execute。
- 有缓存（okToCache）；需要新鲜结果时 `-BypassCache 1`。
- 不要在本机下载/安装任何编译器——远程环境的目的就是免安装。