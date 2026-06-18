<#requires -Version 7
<#
.SYNOPSIS
  Enumerate all languages and per-language compilers from a Compiler-Explorer (godbolt) instance,
  then (re)generate the markdown reference files used by this skill.

.DESCRIPTION
  - GET  {base}/api/languages        -> language list (id/name/extensions)
  - GET  {base}/api/compilers/{lang} -> per-language compiler list (id/name/semver/instructionSet/...)
  Writes one markdown file per language into $OutDir, plus an index file (default: _LANGUAGES.md).
  Safe to re-run: reference files are overwritten.

.EXAMPLE
  .\ce-enum.ps1
  .\ce-enum.ps1 -BaseUrl https://godbolt.org -OutDir references -Index _LANGUAGES.md
#>
param(
  [string]$BaseUrl  = 'https://compiler-explorer.com',
  [string]$OutDir   = (Join-Path $PSScriptRoot '..\references'),
  [string]$Index    = '_LANGUAGES.md',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$headers = @{ Accept = 'application/json' }

if (-not $Force -and -not (Test-Path -LiteralPath $Index)) {}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

Write-Host "Fetching language list from $BaseUrl/api/languages ..."
$langs = Invoke-RestMethod -Uri "$BaseUrl/api/languages" -Headers $headers -TimeoutSec 60

$indexLines = New-Object System.Collections.Generic.List[string]
$indexLines.Add('# Compiler Explorer (CE) — 支持的语言索引')
$indexLines.Add('')
$indexLines.Add("> 数据来源: $BaseUrl  `/api/languages` + `/api/compilers/{lang}`  (抓取时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm'))")
$indexLines.Add('')
$indexLines.Add('| 语言 ID | 语言名 | 扩展名 | 编译器数 | 参考文件 |')
$indexLines.Add('|---|---|---|---|---|')

$total = 0
foreach ($l in ($langs | Sort-Object id)) {
  $safe = $l.id -replace '[\\/:*?"<>|]', '_'
  $path = Join-Path $OutDir "$safe.md"
  try {
    $cps = Invoke-RestMethod -Uri "$BaseUrl/api/compilers/$($l.id)" -Headers $headers -TimeoutSec 60
  } catch {
    $cps = @()
    Write-Warning "compilers for '$($l.id)' failed: $($_.Exception.Message)"
  }
  if ($null -eq $cps) { $cps = @() }
  $n = @($cps).Count
  $total += $n

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# $($l.name) (`"$($l.id)`")")
  $lines.Add('')
  $lines.Add("- 语言 ID: ``$($l.id)``")
  $lines.Add("- 扩展名: ``$($l.extensions -join '`, `')``")
  $lines.Add("- 编译器/解释器数量: $n")
  if ($l.monaco) { $lines.Add("- 编辑器: ``$($l.monaco)``") }
  $lines.Add("- 数据来源: $BaseUrl/api/compilers/$($l.id)  抓取时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
  $lines.Add('')
  if ($n -eq 0) {
    $lines.Add('> 此语言当前未配置任何编译器/解释器。')
  } else {
    $lines.Add('| 编译器 ID | 名称 | 版本(semver) | 指令集 | 类型 |')
    $lines.Add('|---|---|---|---|---|')
    foreach ($c in ($cps | Sort-Object id)) {
      $ver = if ($c.semver) { $c.semver } else { '' }
      $isa = if ($c.instructionSet) { $c.instructionSet } else { '' }
      $typ = if ($c.compilerType) { $c.compilerType } else { '' }
      $lines.Add("| ``$($c.id)`` | $($c.name) | $ver | $isa | $typ |")
    }
  }
  $lines.Add('')
  $lines.Add('> 提交请求时编译器 ID 为: `POST {base}/api/compiler/{id}/compile`')
  Set-Content -LiteralPath $path -Value $lines -Encoding utf8

  $link = "[$safe.md]($safe.md)"
  $indexLines.Add("| ``$($l.id)`` | $($l.name) | ``$($l.extensions -join '`, `')`` | $n | $link |")
  Write-Host ("  {0,-22} {1,4} compilers" -f $l.id, $n)
}

$indexLines.Add('')
$indexLines.Add("---")
$indexLines.Add("共 $($langs.Count) 种语言, $total 个编译器/解释器。源脚本: [scripts/ce-enum.ps1](../scripts/ce-enum.ps1)")
Set-Content -LiteralPath (Join-Path $OutDir $Index) -Value $indexLines -Encoding utf8
Write-Host "Done. Index: $(Join-Path $OutDir $Index)  (languages: $($langs.Count), compilers: $total)"