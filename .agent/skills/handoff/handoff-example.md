<!--
标准交接文档示例（基于 member_variant __at_index 分派重构的实际交接记录整理）
对照 handoff/SKILL.md 的结构：必填节 3 个，条件节 5 个。
带 ✦ 的标题标注"必填"或"有内容才写"。
-->

# Handoff — 20260817-atindex-switch-table

<!-- 状态快照（必填）：一句话概括 + 进度 + 提交 SHA + 工具链/环境 + 时间戳 -->

## 1. 状态快照 ✦ 必填

- **会话完成内容**：完成 `member_variant` 的 `__at_index` 分派重构（switch 跳转表 + 函数表）与 `visit` 实现，CE 回归全绿。
- **当前进度**：C1–C10 验收全部通过；r04 笛卡尔分派探针完成；r05 visit 实现已落地。
- **提交 SHA**：`cbfbd0b`（refactor(member_variant): dispatch __at_index via macro-stamped switch and function table，仅含 member_variant.hpp）。
- **工具链/环境**：C++ / GCC 16.2（ID `g162`）/ 参数 `-std=c++26 -freflection -O2/-O1 -Wall`。
- **时间戳**：2026-08-17。

## 2. 下一步行动 ✦ 必填

<!-- 1-3 件具体可执行的事，逐条可直接执行（含命令/入口/位置），基于 argument 细化 -->

1. 提交 r05：`git add Cplusplus/stdex/utility/member_variant.hpp Cplusplus/stdex/__internal/member_variant/tests/` 后按 Conventional Commits 提交（建议交 `git-commit` 技能生成 message）。
2. 处理 `fixed_string.hpp`：属用户工作区改动，单独提交，不要并入 r05。
3. （可选）用本地提取产物 `C:\Users\Re11a\AppData\Local\Temp\opencode\fptr_constexpr\visit_extract.cpp` 复核 constexpr 分派覆盖。

## 3. 工件清单 ✦ 必填

<!-- 每个工件：路径/URL + 成熟度 draft/review/approved + 一句话用途 -->

| 工件 | 路径 | 成熟度 | 用途 |
| --- | --- | --- | --- |
| 分派测试 | `__internal/member_variant/tests/at_index_dispatch_test.cpp` | approved | C3/C4/C5/C7 验收依据，build=0 exec=0 `ALL PASS` |
| 全套件 | `__internal/member_variant/tests/member_variant_test.cpp` | approved | C6 回归，含新增 `test_visit` |
| 汇编观察 | `docs/ce-tasks/20260817-atindex-switch-table/r03-asm.txt` | review | 80,992 行 Intel 汇编，switch 跳转表证据（C9） |
| 轮次产物 | `docs/ce-tasks/20260817-atindex-switch-table/rNN-source.cpp` 等 | review | 每轮请求/响应/摘要（r01–r05） |
| 本地提取 | `C:\Users\Re11a\AppData\Local\Temp\opencode\fptr_constexpr\visit_extract.cpp` | draft | 反射无关的 visit 提取验证 |

## 4. 未决问题与阻塞 ✦ 有内容才写

<!-- 分类标注 waiting_on_user_input / pending_async_tasks / external_dependency，并注明解阻塞后做什么 -->

- `waiting_on_user_input`：是否提交 r05（含测试与 docs）待用户拍板；确认后执行下一步行动 1。
- 其余无阻塞。

## 5. 关键决策与已否决方案 ✦ 有内容才写

<!-- 决策 + 理由 + 否决了什么及为何，防止重新争论 -->

- **设计决策**：`K = N·M ≤ 256` 用扁平单 switch；`K > 256` 用嵌套。理由：分派机制（switch 内联 vs 函数指针间接调用）决定性能，与查表次数/除法无关。
- **否决方案**：MSVC 1D 函数指针表——flat1D 在 K>256 时 65ns（2.3× 慢于嵌套），flat2D/flat1D 普遍 37–44ns。
- **落地细节**：`__MV_FLAT_LIMIT=256` + `__flat_self` 代理 + `__visit_2`/`__visit_impl`；visit lambda 必须显式 `-> decltype(auto)`（否则 `auto` 去引用，引用返回失败）。

## 6. 操作陷阱 ✦ 有内容才写

<!-- 现象 + 正确做法，避免重踩 -->

- **提交方式**：绕过 `ce-build.ps1`——其 `-Files` 参数承载两个头文件全文超过 Windows 命令行上限。改为手写 request.json 经 `Invoke-RestMethod` POST `https://compiler-explorer.com/api/compiler/g162/compile`。
- **字段名**：files 数组字段是 `filename` + `contents`，不是 `name` / `content`。
- **取汇编**：非执行模式设 `filters.execute=false`、`compilerOptions.executorRequest=false`，asm 在响应顶层 `asm` 数组。

## 7. 工作区脏状态 ✦ 有内容才写

<!-- 未提交文件、已生效 workaround、过期补丁 -->

- 未提交：`Cplusplus/src/main.cpp`（既有）、`Cplusplus/stdex/container/fixed_string.hpp`、`Cplusplus/stdex/utility/member_variant.hpp`（r05）、`docs/`（r05 产物与测试变更）。
- `fixed_string.hpp` 已含用户未提交修复（`inline namespace literals` 双层拆分 + `operator""_fs` 改名 + `#pragma GCC diagnostic ignored "-Wuser-defined-literals"`）。
- **CE 上传无需再打补丁**：原补丁已过期，误加会多出 `} // namespace literals`。

## 8. 已知限制与遗留 ✦ 有内容才写

<!-- 影响后续方法的约束 -->

- L249 `-Wuser-defined-literals` 非 GCC 有效 pragma（应为 `-Wliteral-suffix`），仅警告，暂不处理。
- storage `construct` 用 `reinterpret_cast`，engaged 态无法常量求值 → visit 测试走运行时（与 `ce_bool_niche` 一致）；constexpr 分派已由提取覆盖。

## 9. 建议技能 ✦ 有内容才写

<!-- 技能名 + 调用理由；存在 waiting/pending 时点名 long-waits / self-driven -->

- `compiler-explorer`：继续 CE 回归或新轮次编译验证。
- `git-commit`：r05 提交时生成符合 Conventional Commits 的 message。
- 无 waiting/pending 状态，不需 `long-waits` / `self-driven`。