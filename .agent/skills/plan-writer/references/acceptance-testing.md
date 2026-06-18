# S6 验证/验收：AC 逐条核对指南

独立验收阶段。对照 SPEC 契约与 AC 逐条核对，每条必须有通过证据。

## Iron Law

```
NO BRANCH FINISHING UNTIL ACCEPTANCE TESTING REPORTS ALL CRITERIA PASSED
(OR EXPLICITLY DEFERRED WITH USER APPROVAL).
```

## 核心原则

- 实现完成 ≠ 完成：直到每条 AC 记录了通过证据。
- 失败的 AC 是 blocker，不是 review 意见。
- 单测通过 ≠ AC 通过——两者测的东西不同，不得因"测试都过了"跳过验收。

## 前置条件

- S7 Code Review 已结束，无 Critical/Important 遗留。
- AC 文档存在（SPEC 的 AC 表）。缺失 → 回 S3 用 spec-writer 补齐 AC，获用户确认再回来。

## 执行步骤

1. **输入**：AC 文档路径、当前 git HEAD SHA、仓库根。
2. **独立验收**：换人或独立子代理执行，逐条核对 AC，每条记录通过证据（命令输出 / 截图 / 勾选）。
3. **核对输出**：主代理独立核对验收结果，不接受"应该没问题"的口头结论。

## 结果处理

| 结果 | 动作 |
|------|------|
| 全部 PASS | 进入收尾（finishing-guide.md） |
| 有 FAIL | 回 S4 建修复任务 → 重测 → 重验 |
| Blocked（依赖 AC 未过） | 按 FAIL 处理优先级；依赖通过后自动解锁 |
| Blocked（基础设施缺失） | 停下报告用户，取得明确延期同意后才可继续 |

## 失败修复循环

- 不回上游重做需求（AC 是已冻结契约）。
- **禁止**修改或弱化 AC 以让它通过——AC 难通过说明实现偏离或契约写错：契约错回 S3 修订，实现偏回 S4 修正。
- 逐条宣布失败 AC 的 ID 与描述。
- 循环：S4 修复 → code-review → 重验，直到全绿。

## 红线

- 有 FAIL 仍进入收尾。
- 因难通过而删减/放宽 AC。
- 把"应该没问题"当 PASS。
- 以"单测都过了"跳过验收。