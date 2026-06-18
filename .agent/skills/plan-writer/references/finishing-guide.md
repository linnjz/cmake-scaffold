# 收尾：完成与合并指南

S7 质量门通过后的收尾流程。核心：验证测试 → 呈现选项 → 执行选择 → 清理。

## Step 1：验证测试（必做，先于一切）

运行项目测试套件。失败则停下，不得继续收尾：

```
Tests failing (<N> failures). Must fix before completing.
```

## Step 2：确定基分支

`git merge-base HEAD main`（无则试 master），或直接询问用户。

## Step 3：呈现 4 个结构化选项

不加解释，呈现完整 4 项：

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work
```

## Step 4：执行选择

- **合并本地**：切基分支 → pull → merge → 在合并结果上再跑测试 → 通过后删分支。
- **创建 PR**：push -u origin → gh pr create（摘要 + 验证计划）。保留 worktree。
- **保留原样**：报告分支名与位置，不清理。
- **丢弃**：必须先展示删除内容（分支 / 提交列表 / worktree 路径），用户打字确认后才执行。禁止无确认删除。

## Step 5：清理

- 只对"合并"与"丢弃"清理 worktree；PR 与保留两种情况不清理。

## 收尾前沉淀检查

收尾前检查本次周期是否产生可复用经验（重大边界变更 / 反复出现的坑 / 可复用流程）。有 → 先沉淀到仓库文档或 handoff.md，再执行收尾选项。无 → 明示"无需沉淀"继续。

## 常见错误

- 跳过测试验证就谈收尾 → 合并坏代码。
- 开放式提问（"接下来怎么办？"）→ 用户无从决策；必须给 4 选项。
- 自动清理 worktree → PR/保留场景删掉还要用的工作区。
- 无确认丢弃 → 误删成果。

## 红线

- 测试失败时推进收尾。
- 合并后不验证。
- 无确认删除工作。
- 未要求就强推。