<#
.SYNOPSIS
脚手架：在 docs/specs/ 下创建编号递增的新 SPEC 文件。

.DESCRIPTION
扫描 docs/specs/ 中最高编号并 +1，创建 NNNN-{slug}.md，预填溯源骨架。
正文内容按 references/spec-template.md 撰写。

.PARAMETER Dir
SPEC 目录，默认 docs/specs。不存在则懒创建。

.PARAMETER Title
SPEC 标题（如：微信登录会话管理）。

.PARAMETER Slug
文件名 slug（ASCII）。为空时从标题自动生成。

.PARAMETER Prd
来源 PRD 名称/版本，写入溯源表（可空）。

.PARAMETER Adr
依赖 ADR 编号列表，逗号分隔，写入溯源表（可空）。

.EXAMPLE
./new-spec.ps1 -Title "微信登录会话管理" -Slug wechat-session -Prd "PRD v1.2" -Adr "ADR-0001,ADR-0003"
./new-spec.ps1 -Title "订单状态机重构" -Dir specs
#>

param(
    [Parameter(Mandatory)][string]$Title,
    [string]$Dir = "docs/specs",
    [string]$Slug = "",
    [string]$Prd = "",
    [string]$Adr = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Dir)) {
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
}

$max = 0
Get-ChildItem -LiteralPath $Dir -Filter "????-*.md" -File -ErrorAction SilentlyContinue | ForEach-Object {
    $n = 0
    if ($_.BaseName -match '^(\d{4})-') { $n = [int]$Matches[1] }
    if ($n -gt $max) { $max = $n }
}
$numStr = "{0:D4}" -f ($max + 1)

if (-not $Slug) {
    $Slug = ($Title -replace '[^\w]', '-') -replace '-+', '-' -replace '^-|-$', ''
    if (-not $Slug) { $Slug = "spec" }
}

$date = Get-Date -Format "yyyy-MM-dd"
$file = Join-Path $Dir "$numStr-$Slug.md"

$traceRows = @()
if ($Prd) { $traceRows += "| PRD | $Prd | 待填写覆盖需求编号（如 R1-R3） |" }
if ($Adr) { $traceRows += "| ADR | $Adr | 待填写决策约束 |" }
if ($traceRows.Count -eq 0) {
    $traceRows += "| PRD |  | 待填写来源 PRD 与覆盖需求编号 |"
}
$traceTable = $traceRows -join "`n"

$skeleton = @"
# SPEC-$numStr：$Title

**文档信息**

| 版本 | 日期 | 作者 | 状态 |
|------|------|------|------|
| V1.0.0 | $date |  | Draft |

**溯源**

| 上游文档 | 编号/版本 | 覆盖范围 |
|----------|-----------|----------|
$traceTable

**变更历史**

| 日期 | 变更 | 原因 | 操作人 |
|------|------|------|--------|
| $date | 创建 | 首次编写 |  |

---

## 1. 需求-约束映射表

| 需求ID | PRD 需求 | 依赖 ADR | 契约面 |
|--------|----------|----------|--------|
| R1 |  |  | 接口 |

## 2. 行为契约

### Requirement: {行为名}

{系统 SHALL 一句核心行为}

#### Scenario: {场景名}

- **GIVEN** {前置状态，可选}
- **WHEN** {触发条件}
- **THEN** {期望结果}
- **AND** {附加结果或约束}

## 3. 接口契约

```
{HTTP 方法} {路径}
Request:  { 字段: 类型, 约束 }
Response: { 字段: 类型, 约束 }
Errors:
  {错误码}: {触发条件}
```

## 4. 数据契约

| 字段 | 类型 | 可空 | 索引 | 说明 |
|------|------|------|------|------|
| id | UUID | 否 | PK | 主键 |

## 5. 状态机

| 状态 | 进入条件 | 退出条件 | 用户可见表现 |
|------|----------|----------|--------------|
|  |  |  |  |

## 6. 错误矩阵与边界条件

| 场景 | 触发条件 | 处理方式 | 用户/调用方反馈 |
|------|----------|----------|------------------|
|  |  |  |  |

## 7. 验证锚点

| AC ID | 对应需求/契约 | 描述 | 测试类型 | 前置条件 | 期望结果 |
|-------|---------------|------|----------|----------|----------|
| AC-001 |  |  | API |  |  |

## 8. Good / Base / Bad 用例

| 类型 | 场景 | 输入 | 期望输出 |
|------|------|------|----------|
| Good |  |  |  |
| Base |  |  |  |
| Bad |  |  |  |

## 9. 开放问题

- [ ] {问题} — 需在实现前决策；影响：{若不解决会怎样}

## 10. WBS 输入

| 项 | 数量 | 说明 |
|----|------|------|
| 接口 |  |  |
| 表/实体 |  |  |
| 状态 |  |  |
| 验证锚点 |  |  |
| 迁移 |  |  |
| 估算建议 |  | 人天 |
"@

Set-Content -LiteralPath $file -Value $skeleton -Encoding UTF8
Write-Output "已创建: $file"
Write-Output "按 references/spec-template.md 补齐契约章节，对照 references/checklist.md 自检，并核对溯源表中的 PRD 需求号与 ADR 约束。"