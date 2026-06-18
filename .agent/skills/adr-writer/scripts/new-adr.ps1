<#
.SYNOPSIS
脚手架：在 docs/adr/ 下创建编号递增的新 ADR 文件。

.DESCRIPTION
扫描 docs/adr/ 中最高编号并 +1，创建 NNNN-{slug}.md，预填五要素骨架。
正文内容按 references/adr-template.md 撰写。

.PARAMETER Dir
ADR 目录，默认 docs/adr。不存在则懒创建。

.PARAMETER Title
ADR 标题（如：引入Drools规则引擎）。

.PARAMETER Slug
文件名 slug（ASCII）。为空时从标题自动生成（纯中文标题保留中文，Windows 支持）。

.EXAMPLE
./new-adr.ps1 -Title "引入Drools规则引擎" -Slug drools-rules-engine
./new-adr.ps1 -Title "选用PostgreSQL为主数据库" -Dir decisions/adr
#>

param(
    [Parameter(Mandatory)][string]$Title,
    [string]$Dir = "docs/adr",
    [string]$Slug = ""
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
    if (-not $Slug) { $Slug = "decision" }
}

$date = Get-Date -Format "yyyy-MM-dd"
$file = Join-Path $Dir "$numStr-$Slug.md"

$skeleton = @"
# ADR-$numStr：$Title

- **状态**： Proposed
- **日期**： $date
- **作者**： 
- **最后修改**： $date

## 上下文
[当前面临的技术问题、业务约束与背景环境：团队规模、技术栈版本、性能要求、时间压力]

## 决策
[我们决定采用方案X。具体来说：组件/版本、使用方式、不做范围]

## 后果
正面：
- 
负面：
- 

## 替代方案
[方案A：描述。不选原因：原因]

## 撤销条件
[最重要，勿省略。当以下条件出现时，应重新评估此决策：]

## 关联ADR
[Supersedes / Depends on / Refines / Related to，无则留空]

## 变更历史
| 日期 | 变更类型 | 原因 | 操作人 |
|------|---------|------|--------|
| $date | 创建 | 首次编写 |  |
"@

Set-Content -LiteralPath $file -Value $skeleton -Encoding UTF8
Write-Output "已创建: $file"
Write-Output "按 references/adr-template.md 完善五要素，并同步更新 docs/adr/README.md 索引表。"