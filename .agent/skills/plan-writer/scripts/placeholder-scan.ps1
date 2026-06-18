<#
.SYNOPSIS
占位符扫描：在计划文档中定位占位符，供编制自检（checklist.md）与红线检查。

.DESCRIPTION
逐行扫描目标文档，匹配内置占位符模式（待定/TBD/TODO/待补充/待填写/待确认/类似前文/处理好异常/视情况而定/模板残留 {确切命令} 等），
输出"文件:行号 [模式] 命中行"。发现任一占位符时退出码为 1。
默认扫描 ./docs/plans 下全部 .md；用 -Path 指定单个文件。

.PARAMETER Path
待扫描文件或目录。缺省为 ./docs/plans。

.PARAMETER Pattern
额外正则占位符模式（可多次，追加到内置模式之后）。

.EXAMPLE
./placeholder-scan.ps1

.EXAMPLE
./placeholder-scan.ps1 -Path plan.md -Pattern "待评审"
#>

param(
    [string]$Path = "docs/plans",
    [string[]]$Pattern = @()
)

$ErrorActionPreference = "Stop"

$builtin = @(
    '待定', 'TBD', 'TODO', '待补充', '待填写', '待确认',
    '类似前文', '处理好异常', '视情况而定',
    '\{确切命令\}', '\{确切通过标准\}'
)
$patterns = $builtin + $Pattern

if (Test-Path -LiteralPath $Path -PathType Container) {
    $targets = Get-ChildItem -LiteralPath $Path -Recurse -Filter "*.md" -File
} elseif (Test-Path -LiteralPath $Path -PathType Leaf) {
    $targets = @(Get-Item -LiteralPath $Path)
} else {
    Write-Error "路径不存在: $Path"
    exit 1
}

$hits = 0
foreach ($file in $targets) {
    $lineNo = 0
    Get-Content -LiteralPath $file.FullName -Encoding UTF8 | ForEach-Object {
        $lineNo++
        foreach ($p in $patterns) {
            if ($_ -match $p) {
                Write-Output ("{0}:{1} [{2}] {3}" -f $file.Name, $lineNo, $p, $_.Trim())
                $hits++
                break
            }
        }
    }
}

Write-Output "占位符命中：$hits 处（扫描 $($targets.Count) 个文件）"
if ($hits -gt 0) {
    Write-Output "存在占位符——按 checklist.md 补齐后再进入评审/执行。"
    exit 1
}
Write-Output "无占位符：通过。"