# Human-in-the-loop reproduction loop (PowerShell)
# Copy this file, edit the steps below, and run it.
# The agent runs the script; the user follows prompts in their terminal.
#
# Usage:
#   pwsh hitl-loop.ps1
#
# Two helpers:
#   step "<instruction>"        -> show instruction, wait for Enter
#   capture <var> "<question>"  -> show question, read response into $var
#
# At the end, captured values are printed as KEY=VALUE for the agent to parse.

$ErrorActionPreference = 'Stop'

function step {
    param([string]$instruction)
    Write-Host "`n>>> $instruction"
    Read-Host "    [Enter when done] " | Out-Null
}

function capture {
    param([string]$name, [string]$question)
    Write-Host "`n>>> $question"
    $answer = Read-Host "    > "
    Set-Variable -Name $name -Value $answer -Scope Script
}

# --- edit below ---------------------------------------------------------

step "Open the app at http://localhost:3000 and sign in."

capture ERRORED "Click the 'Export' button. Did it throw an error? (y/n)"

capture ERROR_MSG "Paste the error message (or 'none'):"

# --- edit above ---------------------------------------------------------

Write-Host "`n--- Captured ---"
Write-Host "ERRORED=$ERRORED"
Write-Host "ERROR_MSG=$ERROR_MSG"