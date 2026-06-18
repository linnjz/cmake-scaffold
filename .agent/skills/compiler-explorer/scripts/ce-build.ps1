<#requires -Version 7
<#
.SYNOPSIS
  Compiler Explorer (godbolt) 远程构建/运行客户端：构造请求 -> POST /api/compiler/{id}/compile -> 保存阶段文件 -> 打印摘要。

.DESCRIPTION
  按 skill 约定把每次迭代写入任务目录:
    <AsmBase>/<TaskId>/task.md            任务说明(第一轮创建)
    <AsmBase>/<TaskId>/rNN-source.<ext>   本轮源码
    <AsmBase>/<TaskId>/rNN-request.json   本轮请求体(可回放)
    <AsmBase>/<TaskId>/rNN-response.json  原始响应
    <AsmBase>/<TaskId>/rNN-summary.md     解析摘要
    <AsmBase>/<TaskId>/handoff.md         交接文档(每轮更新)
  退出码: 编译+执行均成功(状态码 0)时返回 0, 否则返回对应非零码。

.PARAMETER BaseUrl        CE 实例地址, 默认 https://compiler-explorer.com (本网络可达; godbolt.org 亦指向它)
.PARAMETER Compiler       编译器/解释器 ID (见 references/<lang>.md), 必填
.PARAMETER SourceFile     源码文件路径 (优先于 -Source)
.PARAMETER Source         内联源码 (与 -Lang 配合推断扩展名)
.PARAMETER Lang           语言 ID (仅推断扩展名用, 如 c++/c/rust/python/go/java/csharp)
.PARAMETER UserArguments  编译器参数, 如 '-O2 -std=c++20 -Wall'
.PARAMETER Execute        执行开关: 编译后运行程序 (executorRequest + filters.execute)
.PARAMETER Asm            请求汇编输出 (仅在不执行时生效; 执行时响应含 buildResult 不含 asm)
.PARAMETER Intel          汇编语法 intel (默认 true), 设 -Intel:$false 得 AT&T
.PARAMETER ShowLabels     汇编含 label 行 (默认 false, 减小体积)
.PARAMETER NoComments     关闭汇编注释 (默认开启注释)
.PARAMETER Stdin          执行时提供给程序的 stdin 文本
.PARAMETER ExecArg        执行时命令行参数, 可重复: -ExecArg a -ExecArg b
.PARAMETER Library        引用的库, JSON 数组文本: '[{"id":"fmt","version":"400"}]'
.PARAMETER Tool           运行的 tools, JSON 数组文本: '[{"id":"clangtidytrunk","args":"-checks=*"}]'
.PARAMETER Files          附加文件, JSON 数组文本: '[{"filename":"a.h","contents":"..."}]'
.PARAMETER BypassCache    强制绕过缓存: 0=不过 1=编译 2=执行
.PARAMETER TaskId         任务 ID, 默认自动生成 yyyyMMdd-HHmmss-<Tag>
.PARAMETER Tag            任务短标签, 默认 'task'
.PARAMETER Round          迭代轮号, 默认 1
.PARAMETER AsmBase        任务目录根, 默认 当前目录/docs/ce-tasks
.PARAMETER TimeoutSec     HTTP 超时秒数, 默认 180

.EXAMPLE
  pwsh scripts/ce-build.ps1 -Compiler g122 -SourceFile main.cpp -UserArguments '-O2 -std=c++20' -Execute -Tag hello -AsmBase docs/ce-tasks
  pwsh scripts/ce-build.ps1 -Compiler python312 -Source 'print(1+1)' -Execute -Round 2 -TaskId 20260811-hello
#>
param(
  [string]$BaseUrl      = 'https://compiler-explorer.com',
  [Parameter(Mandatory)][string]$Compiler,
  [string]$SourceFile,
  [string]$Source,
  [string]$Lang,
  [string]$UserArguments = '',
  [switch]$Execute,
  [switch]$Asm,
  [switch]$Intel        = $true,
  [switch]$ShowLabels,
  [switch]$NoComments,
  [string]$Stdin,
  [string[]]$ExecArg,
  [string]$Library,
  [string]$Tool,
  [string]$Files,
  [int]$BypassCache     = 0,
  [string]$TaskId,
  [string]$Tag          = 'task',
  [int]$Round           = 1,
  [string]$AsmBase      = 'docs/ce-tasks',
  [int]$TimeoutSec      = 180
)

$ErrorActionPreference = 'Stop'

if (-not $SourceFile -and -not $Source) { throw '必须提供 -SourceFile 或 -Source' }
if ($SourceFile) { $code = Get-Content -LiteralPath $SourceFile -Raw -Encoding utf8 } else { $code = $Source }

$extMap = @{
  'c++'='cpp'; 'c'='c'; 'rust'='rs'; 'python'='py'; 'go'='go'; 'java'='java';
  'csharp'='cs'; 'kotlin'='kt'; 'typescript'='ts'; 'javascript'='mjs'; 'zig'='zig';
  'fortran'='f90'; 'ruby'='rb'; 'swift'='swift'; 'd'='d'; 'nim'='nim'; 'ada'='adb';
  'haskell'='hs'; 'ocaml'='ml'; 'scala'='scala'; 'cuda'='cu'; 'assembly'='s';
}
if ($SourceFile) { $ext = [IO.Path]::GetExtension($SourceFile).TrimStart('.') }
elseif ($Lang -and $extMap.ContainsKey($Lang)) { $ext = $extMap[$Lang] }
else { $ext = 'txt' }

if (-not $TaskId) { $TaskId = "{0}-{1}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $Tag }
if ([IO.Path]::IsPathRooted($AsmBase)) { $taskDir = Join-Path $AsmBase $TaskId }
else { $taskDir = Join-Path (Get-Location) (Join-Path $AsmBase $TaskId) }
New-Item -ItemType Directory -Path $taskDir -Force | Out-Null
$stem = 'r{0:D2}' -f $Round

$filters = @{
  commentOnly = (-not $NoComments); directives = $false; demangle = $true
  intel = [bool]$Intel; labels = [bool]$ShowLabels; trim = $false
  binary = ([bool]$Asm -and -not [bool]$Execute); libraryCode = $false; execute = [bool]$Execute
}
if (-not $Asm) { $filters.binary = $false; $filters.labels = $false }

$compilerOptions = @{ executorRequest = [bool]$Execute; skipAsm = (-not $Asm) }
$options = @{
  userArguments = $UserArguments
  compilerOptions = $compilerOptions
  filters = $filters
  executeParameters = @{ args = @($ExecArg | Where-Object { $null -ne $_ }); stdin = $Stdin; runtimeTools = @() }
  tools = @(); libraries = @()
}
if ($Library) { $options.libraries = $Library | ConvertFrom-Json -NoEnumerate }
if ($Tool)    { $options.tools    = $Tool    | ConvertFrom-Json -NoEnumerate }

$body = @{
  source = $code
  options = $options
  lang = $Lang
  allowStoreCodeDebug = $true
  bypassCache = $BypassCache
}
if ($Files) { $body.files = $Files | ConvertFrom-Json -NoEnumerate }

$requestJson = $body | ConvertTo-Json -Depth 20
$headers = @{ Accept = 'application/json' }

# 写任务说明(task.md 仅首轮)
if ($Round -eq 1 -and -not (Test-Path (Join-Path $taskDir 'task.md'))) {
  $taskLines = @(
    "# CE 任务: $TaskId"
    "- 语言: $Lang  |  编译器 ID: ``$Compiler``"
    "- 编译器参数: ``$UserArguments``"
    "- 模式: $(if($Execute){'编译+执行'}else{'编译'})$(if($Asm){' + 汇编'}else{''})"
    "- 实例: $BaseUrl"
    "- 创建: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  )
  Set-Content -LiteralPath (Join-Path $taskDir 'task.md') -Value $taskLines -Encoding utf8
}

# 写本轮文件
Set-Content -LiteralPath (Join-Path $taskDir "$stem-source.$ext") -Value $code -Encoding utf8
Set-Content -LiteralPath (Join-Path $taskDir "$stem-request.json") -Value $requestJson -Encoding utf8

$uri = "$BaseUrl/api/compiler/$Compiler/compile"
Write-Host "POST $uri  (round $Round, task $TaskId)"
$resp = Invoke-WebRequest -Uri $uri -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $requestJson -TimeoutSec $TimeoutSec -UseBasicParsing
if ($resp.Content -is [byte[]]) { $respText = [Text.Encoding]::UTF8.GetString($resp.Content) }
else { $respText = [string]$resp.Content }
$j = $respText | ConvertFrom-Json
Set-Content -LiteralPath (Join-Path $taskDir "$stem-response.json") -Value $respText -Encoding utf8

function Join-Texts($arr) { if ($null -eq $arr) { return '' }; ($arr | ForEach-Object { $_.text }) -join '' }

$build = if ($Execute -and $j.buildResult) { $j.buildResult } else { $j }
$buildCode   = $build.code
$buildErr    = Join-Texts $build.stderr
$buildOut    = Join-Texts $build.stdout
$asmLines    = if ($j.asm) { @($j.asm).Count } else { 0 }
$execCode    = if ($Execute) { $j.code } else { $null }
$execOut     = if ($Execute) { Join-Texts $j.stdout } else { '' }
$execErr     = if ($Execute) { Join-Texts $j.stderr } else { '' }
$execTimeMs  = if ($Execute) { $j.execTime } else { $null }
$timedOut    = $j.timedOut
$didExecute  = $j.didExecute

$summary = New-Object System.Collections.Generic.List[string]
$summary.Add("# Round $Round 摘要 ($TaskId)")
$summary.Add("")
$summary.Add("- 编译器: ``$Compiler``  参数: ``$UserArguments``")
$summary.Add("- 编译退出码: $buildCode$(if($Asm){", 汇编行数: $asmLines"}else{''})$(if($timedOut){", ⚠ timedOut"}else{''})")
if ($buildOut)            { $summary.Add("- 编译 stdout:") ; $summary.Add('```'); $summary.Add($buildOut); $summary.Add('```') }
if ($buildErr)            { $summary.Add("- 编译 stderr(诊断/警告/错误):") ; $summary.Add('```'); $summary.Add($buildErr); $summary.Add('```') }
if ($Execute) {
  $summary.Add("- 执行: didExecute=$didExecute  退出码=$execCode  耗时=$execTimeMs ms")
  if ($execOut) { $summary.Add("- 执行 stdout:"); $summary.Add('```'); $summary.Add($execOut); $summary.Add('```') }
  if ($execErr) { $summary.Add("- 执行 stderr:"); $summary.Add('```'); $summary.Add($execErr); $summary.Add('```') }
}
if ($Asm -and $j.asm) {
  $asmText = ($j.asm | ForEach-Object { $_.text }) -join ''
  $summary.Add("- 汇编片段(前 40 行):"); $summary.Add('```asm')
  ($asmText -split "`n" | Select-Object -First 40) | ForEach-Object { $summary.Add($_) }
  $summary.Add('```')
}
$summary.Add("")
$summary.Add("文件: $stem-source.$ext / $stem-request.json / $stem-response.json / $stem-summary.md")

$summaryPath = Join-Path $taskDir "$stem-summary.md"
Set-Content -LiteralPath $summaryPath -Value $summary -Encoding utf8

# 更新 handoff.md
if ($Execute) {
  if ($buildCode -ne 0) { $status = 'FAIL (编译失败)' }
  elseif ($didExecute -and $execCode -eq 0) { $status = 'PASS (编译+执行通过)' }
  else { $status = 'FAIL (执行失败)' }
} elseif ($buildCode -eq 0) { $status = 'PASS (编译通过)' }
else { $status = 'FAIL (编译失败)' }

$handoff = New-Object System.Collections.Generic.List[string]
$handoff.Add("# Handoff — $TaskId")
$handoff.Add("")
$handoff.Add("- 更新时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  最新轮次: $Round")
$handoff.Add("- 语言: $Lang   编译器 ID: ``$Compiler``   参数: ``$UserArguments``")
$handoff.Add("- 状态: $status")
$handoff.Add("")
$handoff.Add("## 本轮结论")
if ($buildErr) { $handoff.Add("- 编译诊断:"); $buildErr -split "`n" | Select-Object -First 12 | ForEach-Object { $handoff.Add("  $_") } }
if ($Execute) {
  $handoff.Add("- 执行退出码: $execCode   stdout: ``$($execOut.Trim())``")
  if ($execErr) { $handoff.Add("- 执行 stderr: ``$($execErr.Trim())``") }
}
if ($Asm -and $j.asm) { $handoff.Add("- 汇编行数: $asmLines, 摘要见 $stem-summary.md") }
$handoff.Add("- 阶段文件: $stem-source.$ext / $stem-request.json / $stem-response.json / $stem-summary.md")
$handoff.Add("")
$handoff.Add("## 下一轮建议(由协作 agent 填充)")
$handoff.Add("- [ ] 待办1: <修复点/验证项>")
$handoff.Add("")
$handoff.Add(("> 上一轮: r{0:D2}  →  下一轮参数: 建议 -Round {1} 沿用 -TaskId $TaskId" -f ($Round - 1), ($Round + 1)))
Set-Content -LiteralPath (Join-Path $taskDir 'handoff.md') -Value $handoff -Encoding utf8

# 终端打印摘要
$summary | ForEach-Object { Write-Host $_ }
if ($buildErr)        { Write-Warning "编译诊断: $($buildErr.Trim())" }
if ($Execute -and $execErr) { Write-Warning "执行 stderr: $($execErr.Trim())" }
Write-Host "Task dir: $taskDir"

if ($Execute) {
  if ($buildCode -ne 0) { exit $buildCode }
  elseif (-not $didExecute -or $execCode -ne 0) { exit ($execCode ?? 1) }
  exit 0
}
exit $buildCode