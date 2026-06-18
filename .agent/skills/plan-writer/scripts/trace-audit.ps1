<#
.SYNOPSIS
溯源审计：检查 plan.md 任务是否都有 AC 引用（无孤儿），且引用的 AC 在 SPEC 中已定义（无悬空）。

.DESCRIPTION
- 无孤儿：每个 Task 块必须引用至少一个 AC-xxx。
- 无悬空：若给 -SpecPath，plan 引用的 AC 必须出现在 SPEC 中。
输出审计报告；存在问题时退出码为 1。支撑 Phase 3 对齐门与 checklist.md"无孤儿"自检。

.PARAMETER PlanPath
计划文档路径。缺省为 ./docs/plans 下最新修改的 plan.md。

.PARAMETER SpecPath
SPEC 文档路径（可空）。提供后校验悬空 AC 引用。

.EXAMPLE
./trace-audit.ps1 -PlanPath docs/plans/20260821-wechat-session/plan.md -SpecPath docs/specs/spec-0001.md
#>

param(
    [string]$PlanPath = "",
    [string]$SpecPath = ""
)

$ErrorActionPreference = "Stop"

if (-not $PlanPath) {
    $latest = Get-ChildItem -Path "docs/plans" -Recurse -Filter "plan.md" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) { Write-Error "未找到 plan.md，请用 -PlanPath 指定" }
    $PlanPath = $latest.FullName
}
if (-not (Test-Path -LiteralPath $PlanPath)) { Write-Error "计划文件不存在: $PlanPath" }

$planLines = Get-Content -LiteralPath $PlanPath -Encoding UTF8
$taskRegex = '^#{2,4}\s*Task\s+'

$orphanTasks = @()
$usedAc = @()
$currentTask = ""
$currentHasAc = $false
foreach ($line in $planLines) {
    if ($line -match $taskRegex) {
        if ($currentTask -and -not $currentHasAc) { $orphanTasks += $currentTask }
        $currentTask = $line.Trim()
        $currentHasAc = $false
    }
    if ($line -match 'AC-\d+') {
        $currentHasAc = $true
        foreach ($m in [regex]::Matches($line, 'AC-\d+')) { $usedAc += $m.Value }
    }
}
if ($currentTask -and -not $currentHasAc) { $orphanTasks += $currentTask }

$usedAc = $usedAc | Sort-Object -Unique
$taskCount = ($planLines | Where-Object { $_ -match $taskRegex }).Count

$dangling = @()
if ($SpecPath) {
    if (-not (Test-Path -LiteralPath $SpecPath)) { Write-Error "SPEC 文件不存在: $SpecPath" }
    $specText = Get-Content -LiteralPath $SpecPath -Raw -Encoding UTF8
    foreach ($ac in $usedAc) {
        if ($specText -notmatch [regex]::Escape($ac)) { $dangling += $ac }
    }
}

Write-Output "## 溯源审计报告"
Write-Output "计划：$PlanPath"
if ($SpecPath) { Write-Output "SPEC：$SpecPath" }
Write-Output ""
Write-Output "任务块数：$taskCount"
Write-Output "唯一 AC 引用：$($usedAc.Count) 个"

if ($orphanTasks.Count -gt 0) {
    Write-Output "`n### 无溯源任务（未引用任何 AC）："
    $orphanTasks | ForEach-Object { Write-Output "  - $_" }
} else {
    Write-Output "`n无孤儿：所有任务均有 AC 引用。"
}

if ($dangling.Count -gt 0) {
    Write-Output "`n### 悬空 AC（SPEC 未定义）："
    $dangling | ForEach-Object { Write-Output "  - $_" }
} elseif ($SpecPath) {
    Write-Output "无悬空：所有引用 AC 均已在 SPEC 定义。"
}

$hasIssue = $orphanTasks.Count -gt 0 -or $dangling.Count -gt 0
Write-Output ""
Write-Output "结论：$(if ($hasIssue) { '不通过——存在无溯源任务或悬空引用' } else { '通过' })"
if ($hasIssue) { exit 1 }