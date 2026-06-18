<#
.SYNOPSIS
Gate 证据验证器：当次运行验证命令，输出证据块。

.DESCRIPTION
实现 gates-and-loops.md 的 IDENTIFY→RUN→READ→VERIFY 四步：
- RUN：当次完整运行验证命令（禁止用先前结果替代）。
- READ：读取完整输出，检查退出码，可选按正则统计失败数。
- VERIFY：退出码 + 失败数判定 PASS/FAIL。
- 输出证据块（命令/退出码/失败数/结论），可直接粘贴进 Gate 退出声明。

.PARAMETER Command
验证命令字符串（经 cmd.exe /c 执行，支持 npm test / pytest 等）。

.PARAMETER Description
验证说明（如"S5 测试 Gate"），用于证据块标签。

.PARAMETER FailurePattern
可选正则，统计输出中的失败行数（如 '(FAIL|Error:)'）。缺省仅依据退出码判定。

.PARAMETER ShowOutput
附加完整输出到证据块。

.EXAMPLE
./gate-check.ps1 -Command "npm test" -Description "S5 测试 Gate" -FailurePattern "FAIL"

.EXAMPLE
./gate-check.ps1 -Command "pytest tests -q" -ShowOutput
#>

param(
    [Parameter(Mandatory)][string]$Command,
    [string]$Description = "Gate 验证",
    [string]$FailurePattern = "",
    [switch]$ShowOutput
)

$ErrorActionPreference = "Stop"

$started = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$output = & cmd.exe /c $Command 2>&1
$exitCode = $LASTEXITCODE
$finished = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$failCount = 0
if ($FailurePattern) {
    $failCount = ($output | Where-Object { $_ -match $FailurePattern }).Count
}

$verdict = "PASS"
if ($exitCode -ne 0 -or ($FailurePattern -and $failCount -gt 0)) {
    $verdict = "FAIL"
}

$block = @"
## Gate 证据：$Description

- 运行时间：$started ~ $finished
- 命令：$Command
- 退出码：$exitCode
- 失败计数：$(if ($FailurePattern) { "$failCount (模式: $FailurePattern)" } else { "未统计（未给 FailurePattern）" })
- 结论：$verdict
"@

if ($ShowOutput) {
    $block += "`n`n### 输出`n````````n" + ($output -join "`n") + "`n````````"
}

Write-Output $block

if ($verdict -eq "FAIL") {
    Write-Output "Gate 未通过：$Description（退出码 $exitCode，失败 $failCount）"
    exit 1
}

Write-Output "Gate 已通过：$Description"