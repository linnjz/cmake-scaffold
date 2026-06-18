<#
.SYNOPSIS
计算代码评审的 git 范围（BASE_SHA/HEAD_SHA）并输出 diff 统计。

.DESCRIPTION
默认按功能分支场景计算：BASE = merge-base(Target, HEAD)，HEAD = HEAD。
-Uncommitted 时改为列出未提交改动（工作区+暂存区 vs HEAD），并省略 BASE/HEAD。

.PARAMETER Target
主分支引用，默认 origin/main。

.PARAMETER Uncommitted
评审未提交改动。

.EXAMPLE
./review-scope.ps1
./review-scope.ps1 -Target origin/master
./review-scope.ps1 -Uncommitted
#>

param(
    [string]$Target = "origin/main",
    [switch]$Uncommitted
)

$ErrorActionPreference = "Stop"

if ($Uncommitted) {
    Write-Output "=== 未提交改动（工作区+暂存区 vs HEAD） ==="
    git diff --stat HEAD
    exit 0
}

$baseLine = (git merge-base $Target HEAD 2>$null | Select-Object -First 1)
if (-not $baseLine) {
    Write-Warning "merge-base($Target) 失败（分支未推送或引用不存在），回退 BASE = HEAD~1"
    $baseLine = git rev-parse "HEAD~1"
}
$headLine = git rev-parse HEAD

Write-Output "BASE_SHA=$baseLine"
Write-Output "HEAD_SHA=$headLine"
Write-Output ""
git diff --stat "$baseLine..$headLine"