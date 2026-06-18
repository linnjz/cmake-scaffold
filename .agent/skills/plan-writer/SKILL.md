---
name: plan-writer
description: >-
  当用户要求制定项目/执行计划、排期、里程碑、阶段计划、WBS 任务拆解、迭代计划，或要求把
  已确认的 PRD/ADR/SPEC 编排成可执行的阶段流程（含 PRD→ADR→SPEC→实施 的分阶段执行、
  coding-checklist、测试验证、自检 code review、handoff 交接、持续迭代回流）时使用。
  也用于计划修订、阶段推进、排期超限时的范围重估（PLAN 反推 PRD）。Use ONLY when 需要
  产出管理视角的计划文档：纯需求讨论用 prd-writer，纯架构决策用 adr-writer，纯实现规格用
  spec-writer。
---

# 项目计划制定（plan-writer）

## 定位（边界）

PLAN 是 PRD（为什么做）、ADR（怎么做）、SPEC（具体长什么样）、PLAN（什么时候交付）的第四级——**管理视角**。它把 SPEC 的 WBS 输入变成"谁在何时按什么顺序完成什么"，并通过反馈回路反推上游。

- **承接**：SPEC 的 WBS 输入表（接口数/表数/AC 数/估算）与 AC 验证锚点。
- **驱动**：阶段执行 → 测试 → 验证/验收 → 自检 + Code Review。
- **回流**：排期超限 → 反推 PRD 砍需求；SPEC 发现 ADR 撑不住 → 反推 ADR 新建决策。

**不属于 PLAN**：接口/数据契约（spec-writer）、技术选型权衡（adr-writer）、需求痛点（prd-writer）。计划引用而非复制这些内容。

## 核心模型：阶段线 + 门 + 回流

一个 PLAN = 主线（线性阶段）+ 贯穿机制（交接与迭代）。

**主线**（每阶段有进入/退出条件 Gate）：

```
S0 计划编制 → S1 需求(PRD) → S2 架构(ADR) → S3 规格(SPEC)
→ S4 实施(coding-checklist) → S5 测试 → S6 验证/验收 → S7 质量门(自检+Code Review)
```

**贯穿机制**：
- **Handoff 交接**：每个 Gate 后、每个会话边界更新 `handoff.md`。
- **持续迭代**：显式回流触发器（见 `references/gates-and-loops.md`），任何回流先更新上游文档再回归执行。

**起点推断**：先扫描已有 PRD/ADR/SPEC/AC，决定从哪个阶段开始——上游文档已存在时，计划从实施阶段起，不虚设空阶段。

## 触发条件

1. 用户要求制定/修订计划、排期、里程碑、阶段流程、WBS。
2. 用户要求把 PRD/ADR/SPEC 编排成"PRD→ADR→SPEC→实施"的分阶段执行流程。
3. 需要测试、验证、自检 code review、handoff 交接、持续迭代的项目执行组织。

## 工作流

### Phase 1：输入核对（溯源门）

1. 扫描仓库已有产物：PRD？ADR？SPEC？AC？——确定起点阶段（吸收 artifact 推断：有 spec.md+tasks.md → 从 S4 起）。
2. 读取 SPEC 的 WBS 输入表与 AC 表；缺失则提示先用 `spec-writer` 补齐，不凭空编造输入。
3. 提取约束：PRD 范围冻结项、ADR 关键决策、外部依赖。
4. 输出起点推断表，与用户对齐后进入编制。

### Phase 2：计划编制

加载 `references/plan-template.md` 生成 PLAN。必须包含：
- **阶段表**（S0-S7：产出物 / 进入条件 / 退出条件 Gate / 责任人），被跳过的阶段整行标记"已跳过+依据"。
- **里程碑**（关联阶段 / 计划日期 / 外部依赖 / 缓冲）。
- **WBS 任务分解**：每个任务含 coding-checklist 勾选项 + 确切命令 + 期望输出 + 关联 AC。
- **风险与缓冲**：风险登记表 + 缓冲天数 + 外部依赖清单（含交付时间）。
- **回流规则**：六类触发器（测试失败 / AC 红 / 排期超限 / ADR 撑不住 / review 架构问题 / 依赖延期）。
- **交接约定**：每 Gate 后更新 handoff.md。

**无占位符**：任务步骤必须完整（确切命令 + 期望输出），禁止"待定 / 处理好异常 / 类似前文"。

### Phase 3：计划评审（对齐门）

对照 PRD/ADR/SPEC 逐项核对：
- **无孤儿**：每个里程碑、任务可溯源到 SPEC 需求 / AC ID。
- **无超界**：计划引用契约而非重新定义（不复制 SPEC 章节）。
- **可执行**：每个任务有验证锚点，每个 Gate 有证据要求。
与用户确认后冻结计划。未确认不进入执行。

### Phase 4：阶段执行与推进

按阶段表推进，遵守 `references/gates-and-loops.md` 的 Gate 判据：
- **执行组织（S4）**：按 `references/execution-guide.md` 分派子代理，主代理只协调不实现。
- **推进由产出物触发**：阶段产出物就位 + 证据齐全才切换阶段。
- **测试（S5）**：按 `references/tdd-guide.md` 走红绿循环，开发自证。
- **验证（S6）**：按 `references/acceptance-testing.md` 逐条核对 AC，确认契约。
- **自检 + Code Review（S7）**：Critical/Important 未解决不得推进。
- **收尾**：S7 通过后按 `references/finishing-guide.md` 决策合并/PR/丢弃。
- **证据先于断言**：每个 Gate 退出声明必须附当次运行的输出，禁止"应该/大概"、禁止用先前结果替代。

### Phase 5：交接与迭代

- 每个 Gate 后更新 `handoff.md`（进度 / 未决事项 / 下一步）；会话中断读 handoff.md 续跑；任务完成标注 `[DONE]`。
- 回流触发时：按 `references/gates-and-loops.md` 先更新受影响的上游文档（PRD/ADR/SPEC），再回归执行。
- 连续两轮同阶段回流未通过 → 停下向用户报告，不硬扛。

## 红线

- 任务无溯源：对不上 PRD/SPEC/AC。
- 阶段无 Gate：只列任务清单，不定义完成条件。
- 无风险与缓冲：把 PLAN 写成 TODO。
- 用"类似前文"代替完整 coding-checklist。
- 用先前证据 / 口头报告代替当次验证（Iron Law）。
- 排期超限硬扛，不触发"PLAN 反推 PRD"回流。
- 计划未评审就进入执行。

## 底线

**PLAN 是管理视角的节奏表**：阶段线保证推进，Gate 保证质量，回流保证对上游的反推，handoff 保证上下文不丢。它让 PRD/ADR/SPEC 的意图真正落到"何时、谁、按什么顺序交付"。

## 资源索引

| 文件 | 用途 |
|------|------|
| `references/plan-template.md` | 完整模板（溯源 + 起点推断 + 阶段表 + 里程碑 + WBS + 风险 + 回流 + 依赖 + 交接） |
| `references/gates-and-loops.md` | Gate 判据（证据先于断言）、阶段推进产出物、回流触发器细则 |
| `references/checklist.md` | 编制自检 + 阶段推进自检 |
| `references/execution-guide.md` | S4 执行组织：子代理分派 / 上下文保护 / 模型分层 |
| `references/tdd-guide.md` | S5 测试：红绿循环 + 反合理化 |
| `references/acceptance-testing.md` | S6 验收：AC 逐条证据 + 失败修复循环 |
| `references/finishing-guide.md` | 收尾：合并/PR/丢弃决策 + 清理 |
| `scripts/new-plan.ps1` | 脚手架：自动创建 plan.md + progress.md + handoff.md |
| `scripts/gate-check.ps1` | Gate 证据验证：当次运行命令 → 退出码/失败数 → 证据块 |
| `scripts/placeholder-scan.ps1` | 占位符扫描：定位"待定/TBD/类似前文"等 |
| `scripts/trace-audit.ps1` | 溯源审计：无孤儿（任务有 AC）+ 无悬空（AC 已在 SPEC） |