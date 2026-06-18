<#
.SYNOPSIS
脚手架：在 docs/plans/ 下创建新计划的 plan.md + progress.md + handoff.md。

.DESCRIPTION
创建 docs/plans/{yyyyMMdd}-{slug}/ 目录（懒创建），生成三件套：
- plan.md      计划正文骨架（按 references/plan-template.md 补齐）
- progress.md  阶段推进跟踪（phase/blocked/assignee + 历史表）
- handoff.md   交接文档（每 Gate 后、会话中断时更新）

.PARAMETER Dir
计划根目录，默认 docs/plans。不存在则懒创建。

.PARAMETER Title
计划标题（如：微信登录会话管理上线）。

.PARAMETER Slug
文件名 slug（ASCII）。为空时从标题自动生成。

.PARAMETER Prd
来源 PRD 名称/版本（可空）。

.PARAMETER Adr
依赖 ADR 编号列表，逗号分隔（可空）。

.PARAMETER Spec
来源 SPEC 编号（可空）。

.EXAMPLE
./new-plan.ps1 -Title "微信登录会话管理上线" -Slug wechat-session -Prd "PRD v1.2" -Adr "ADR-0001" -Spec "SPEC-0001"
#>

param(
    [Parameter(Mandatory)][string]$Title,
    [string]$Dir = "docs/plans",
    [string]$Slug = "",
    [string]$Prd = "",
    [string]$Adr = "",
    [string]$Spec = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Dir)) {
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
}

if (-not $Slug) {
    $Slug = ($Title -replace '[^\w]', '-') -replace '-+', '-' -replace '^-|-$', ''
    if (-not $Slug) { $Slug = "plan" }
}

$date = Get-Date -Format "yyyy-MM-dd"
$stamp = Get-Date -Format "yyyyMMdd"
$planId = "$stamp-$Slug"
$planDir = Join-Path $Dir $planId

if (Test-Path -LiteralPath $planDir) {
    Write-Error "目录已存在: $planDir"
    exit 1
}
New-Item -ItemType Directory -Path $planDir -Force | Out-Null

$traceRows = @()
if ($Prd)  { $traceRows += "| PRD | $Prd | 待填写覆盖需求编号 |" }
if ($Adr)  { $traceRows += "| ADR | $Adr | 待填写决策约束 |" }
if ($Spec) { $traceRows += "| SPEC | $Spec | WBS 输入来源 |" }
if ($traceRows.Count -eq 0) {
    $traceRows += "| PRD |  | 待填写来源 PRD 与覆盖需求编号 |"
}
$traceTable = $traceRows -join "`n"

$planFile = Join-Path $planDir "plan.md"
$progressFile = Join-Path $planDir "progress.md"
$handoffFile = Join-Path $planDir "handoff.md"

$planSkeleton = @"
# PLAN：$Title

**文档信息**

| 版本 | 日期 | 作者 | 状态 |
|------|------|------|------|
| V1.0.0 | $date |  | Draft |

**溯源**

| 上游文档 | 编号/版本 | 说明 |
|----------|-----------|------|
$traceTable

**变更历史**

| 日期 | 变更 | 原因 | 操作人 |
|------|------|------|--------|
| $date | 创建 | 首次编写 |  |

---

## 1. 起点推断

| 已存在 | 结论 |
|--------|------|
| PRD / ADR / SPEC / AC 待扫描 | 待确定起始阶段 |

## 2. 阶段表

| 阶段 | 产出物 | 进入条件 | 退出条件（Gate） | 责任人 |
|------|--------|----------|------------------|--------|
| S0 计划编制 | 本计划 | SPEC 已确认 + WBS 输入齐 | 计划评审通过 |  |
| S1 需求 | PRD | 计划已批 | PRD 评审通过 |  |
| S2 架构 | ADR | PRD 冻结 | ADR 评审通过 |  |
| S3 规格 | SPEC | PRD+ADR 齐 | SPEC 自检通过 |  |
| S4 实施 | 代码 + coding-checklist | 任务清单就绪 | 验证锚点通过 |  |
| S5 测试 | 测试结果 | 产出物可测 | 无 P0/P1 失败 |  |
| S6 验证/验收 | 验收报告 | 测试通过 | AC 全绿 |  |
| S7 质量门 | 自检 + Code Review 结论 | 验证通过 | 无 Critical/Important 遗留 |  |

## 3. 里程碑

| 里程碑 | 关联阶段 | 计划日期 | 外部依赖 | 缓冲 |
|--------|----------|----------|----------|------|
| M1 计划冻结 | S0 |  |  |  |

## 4. WBS 任务分解

### Task T-001：[任务名]（阶段 S4，关联 AC-001）

- [ ] **步骤 1：[动作]**：[完整内容/命令]
- [ ] **步骤 2：运行验证**
  运行：`{确切命令}`
  期望：`{确切通过标准}`

## 5. 风险与缓冲

| 风险 | 可能性 | 影响 | 应对 | 缓冲天数 |
|------|--------|------|------|----------|
|  |  |  |  |  |

## 6. 回流规则

| 触发条件 | 动作 |
|----------|------|
| 测试失败(P0/P1) | 回 S4/S5 修正→回归 |
| 验证不通过(AC 红) | 回 SPEC 澄清 或 回实施修正 |
| 排期超限 | PLAN 反推 PRD 砍需求 |
| SPEC 发现 ADR 撑不住 | 新增 ADR 后回归 |
| Code Review 架构级问题 | 回 S2 重估 |
| 外部依赖延期 | 里程碑重排 |

## 7. 外部依赖清单

| 依赖 | 类型 | 交付时间 | 责任人 |
|------|------|----------|--------|
|  |  |  |  |

## 8. 交接约定

- 每个 Gate 通过后更新 handoff.md；会话中断读 handoff.md 续跑；任务完成标注 [DONE]。
"@

$progressSkeleton = @"
---
phase: S0 计划编制
blocked: false
blocked_reason: ""
assignee: ""
plan: $planId
updated_at: $date
---

# 进度：$Title

## 当前状态

| 字段 | 值 |
|------|-----|
| 阶段 | S0 计划编制 |
| 阻塞 | 否 |
| 责任人 |  |
| 计划 | $planId |

## 产出物清单

- [ ] plan.md（S0）
- [ ] PRD（S1）
- [ ] ADR（S2）
- [ ] SPEC（S3）
- [ ] 代码 + coding-checklist（S4）
- [ ] 测试结果（S5）
- [ ] 验收报告 / AC 勾选（S6）
- [ ] 自检 + Code Review 结论（S7）

## 阶段历史

| 日期 | 阶段 | 方式 | 备注 |
|------|------|------|------|
| $date | S0 计划编制 | 创建 |  |
"@

$handoffSkeleton = @"
# 交接：$Title（$planId）

**状态**：[进行中 / DONE]

**当前阶段**：S0 计划编制

## 进度摘要
- [ ] 计划编制完成，已过评审门
- [ ] 上游文档（PRD/ADR/SPEC）就绪

## 未决事项
- [ ] {待用户确认/待补充的信息}

## 下一步
- {明确的下一个动作 + 所需输入}

## 产物位置
- 计划：plan.md
- 进度：progress.md
- 本文件：handoff.md（每个 Gate 后更新）
"@

Set-Content -LiteralPath $planFile -Value $planSkeleton -Encoding UTF8
Set-Content -LiteralPath $progressFile -Value $progressSkeleton -Encoding UTF8
Set-Content -LiteralPath $handoffFile -Value $handoffSkeleton -Encoding UTF8
Write-Output "已创建计划目录: $planDir"
Write-Output "  plan.md / progress.md / handoff.md"
Write-Output "按 references/plan-template.md 补齐阶段表与 WBS，对照 references/checklist.md 自检，评审通过后开始阶段执行。"