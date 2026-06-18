<#
.SYNOPSIS
    Detect MSVC/vcpkg/Qt environment for CMake builds on Windows.
.DESCRIPTION
    Detection priority: env vars > cache > auto-detect > null.
    Use -CacheVcpkgRoot or -CacheQtSdkDir to persist user-corrected paths.
    Run from project root.
.EXAMPLE
    # Read mode — detect paths
    & "scripts/detect-env.ps1" | ConvertFrom-Json

    # Write mode — cache a user-provided path for future runs
    & "scripts/detect-env.ps1" -CacheVcpkgRoot "D:/tools/vcpkg"
    & "scripts/detect-env.ps1" -CacheQtSdkDir "D:/Qt/6.6.2/msvc2019_64"
#>

param(
    [string]$CacheVcpkgRoot,
    [string]$CacheQtSdkDir
)

# ── Cache file path ────────────────────────────────────────────
$CacheDir = "$env:USERPROFILE\.cmake-build"
$CacheFile = "$CacheDir\cache.json"

# ── Cache helpers ──────────────────────────────────────────────
function Read-Cache {
    if (Test-Path $CacheFile) {
        try { return Get-Content $CacheFile -Raw | ConvertFrom-Json } catch { }
    }
    return $null
}

function Write-Cache($updates) {
    if (-not (Test-Path $CacheDir)) { New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null }
    $cache = Read-Cache
    if (-not $cache) { $cache = @{} }
    foreach ($key in $updates.Keys) { $cache.$key = $updates.$key }
    $cache.last_updated = (Get-Date -Format "o")
    $cache | ConvertTo-Json | Set-Content $CacheFile
}

# ── Handle write mode ──────────────────────────────────────────
$writeMode = $CacheVcpkgRoot -or $CacheQtSdkDir
if ($writeMode) {
    $updates = @{}
    if ($CacheVcpkgRoot) { $updates.vcpkg_root = $CacheVcpkgRoot }
    if ($CacheQtSdkDir)  { $updates.qt_sdk_dir  = $CacheQtSdkDir }
    Write-Cache $updates
    Write-Host "cached"
    exit 0
}

# ── Detection helpers ──────────────────────────────────────────
function Find-Msvc {
    # vswhere (VS 2017+)
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $vsInfo = & $vswhere -latest -prerelease -format json -products * | ConvertFrom-Json
        if ($vsInfo) {
            $clCandidates = Get-ChildItem -Path "$($vsInfo[0].installationPath)\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe" -ErrorAction SilentlyContinue
            if ($clCandidates) {
                $clPath = $clCandidates[-1].FullName
                $ver = [regex]::Match($clPath, 'MSVC\\(\d+\.\d+\.\d+)').Groups[1].Value
                if (-not $ver) { $ver = "unknown" }
                return @{ cl_path = $clPath; version = $ver }
            }
        }
    }
    # Fallback: common VS 2022 install paths
    $vsRoots = @("${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Enterprise",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Professional",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Community")
    foreach ($root in $vsRoots) {
        $candidates = Get-ChildItem -Path "$root\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe" -ErrorAction SilentlyContinue
        if ($candidates) { return @{ cl_path = $candidates[-1].FullName; version = "unknown" } }
    }
    return @{ cl_path = $null; version = $null }
}

function Find-Vcpkg {
    # 1) Env var (highest priority)
    if ($env:VCPKG_ROOT -and (Test-Path $env:VCPKG_ROOT)) {
        return @{ root = $env:VCPKG_ROOT; triplet = "x64-windows-static-md" }
    }
    # 2) Cache
    $cache = Read-Cache
    if ($cache -and $cache.vcpkg_root -and (Test-Path $cache.vcpkg_root)) {
        return @{ root = $cache.vcpkg_root; triplet = "x64-windows-static-md" }
    }
    # 3) Common install paths
    $commonPaths = @("$env:LOCALAPPDATA/vcpkg", "$env:USERPROFILE/vcpkg", "C:/dev/vcpkg", "C:/vcpkg", "$env:HOMEDRIVE/vcpkg")
    foreach ($p in $commonPaths) {
        if (Test-Path $p) { return @{ root = $p; triplet = "x64-windows-static-md" } }
    }
    return @{ root = $null; triplet = $null }
}

function Find-Qt {
    # 1) Env var (highest priority)
    if ($env:QTDIR -and (Test-Path "$env:QTDIR/bin/qmake.exe")) {
        return @{ sdk_dir = $env:QTDIR }
    }
    # 2) Cache
    $cache = Read-Cache
    if ($cache -and $cache.qt_sdk_dir -and (Test-Path "$($cache.qt_sdk_dir)/bin/qmake.exe")) {
        return @{ sdk_dir = $cache.qt_sdk_dir }
    }
    # 3) Registry
    $qtReg = @("HKLM:\SOFTWARE\Qt\Qt6", "HKLM:\SOFTWARE\WOW6432Node\Qt\Qt6")
    foreach ($reg in $qtReg) {
        if (Test-Path $reg) {
            $ver = Get-ChildItem $reg | Select-Object -First 1
            if ($ver) {
                $sdkPath = (Get-ItemProperty "$reg\$($ver.PSChildName)").InstallDir
                if ($sdkPath -and (Test-Path "$sdkPath/bin/qmake.exe")) { return @{ sdk_dir = $sdkPath } }
            }
        }
    }
    return @{ sdk_dir = $null }
}

function Find-Generator {
    if (Get-Command "ninja" -ErrorAction SilentlyContinue) { return "Ninja" }
    if ($env:VSCMD_VER) { return "NMake Makefiles" }
    if (Test-Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe") { return "Visual Studio 17 2022" }
    return "NMake Makefiles"
}

function Find-Presets {
    $presets = @()
    foreach ($f in @("CMakePresets.json", "CMakeUserPresets.json")) {
        if (Test-Path $f) {
            try {
                $content = Get-Content $f -Raw | ConvertFrom-Json
                if ($content.configurePresets) {
                    foreach ($p in $content.configurePresets) { if (-not $p.hidden) { $presets += $p.name } }
                }
            } catch { }
        }
    }
    return $presets
}

# ── Main (read mode) ───────────────────────────────────────────
$result = @{
    msvc      = Find-Msvc
    vcpkg     = Find-Vcpkg
    qt        = Find-Qt
    generator = Find-Generator
    presets   = Find-Presets
}
$result | ConvertTo-Json -Depth 3
