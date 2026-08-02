<#
.SYNOPSIS
    Builds RogueKeys into a distributable .love file and a fused Windows exe.

.DESCRIPTION
    1. Stages the game source (excluding .git, tools/, tests/, docs/, dist/,
       .verify/ and any markdown files) into dist/_stage.
    2. Zips the staged tree to dist/RogueKeys.love with main.lua at the zip
       root -- a nested folder is the classic mistake that produces a .love
       LOVE cannot run.
    3. Verifies the .love actually boots by running it with --test and
       checking the exit code, before it's trusted enough to fuse.
    4. Fuses it onto the LOVE executable to produce dist/win64/RogueKeys.exe
       (`copy /b love.exe+RogueKeys.love RogueKeys.exe`, the packaging method
       documented on the LOVE wiki and used by Balatro et al.), then copies
       LOVE's runtime DLLs and license.txt alongside it.

    Never downloads LOVE itself -- delegates to tools/get-love.ps1 for that.

.PARAMETER LovePath
    Path to love.exe. Defaults to whatever tools/get-love.ps1 resolves
    (downloading a portable copy on first run if needed).

.PARAMETER Clean
    Remove dist/ before building.

.EXAMPLE
    pwsh tools/build.ps1
.EXAMPLE
    pwsh tools/build.ps1 -LovePath "C:\love-11.5-win64\love.exe" -Clean
#>
[CmdletBinding()]
param(
    [string]$LovePath,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$distDir = Join-Path $repoRoot "dist"
$stageDir = Join-Path $distDir "_stage"
$loveFile = Join-Path $distDir "RogueKeys.love"
$win64Dir = Join-Path $distDir "win64"
$fusedExe = Join-Path $win64Dir "RogueKeys.exe"

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Fail {
    param([string]$Message)
    Write-Host "BUILD FAILED: $Message" -ForegroundColor Red
    exit 1
}

if ($Clean -and (Test-Path $distDir)) {
    Write-Step "Cleaning $distDir"
    Remove-Item -Recurse -Force $distDir
}

New-Item -ItemType Directory -Force -Path $distDir | Out-Null

# --- 1. Resolve the LOVE runtime -------------------------------------------
if (-not $LovePath) {
    Write-Step "No -LovePath given; resolving via tools/get-love.ps1"
    # get-love.ps1 is pure PowerShell (no native exe involved), so
    # $LASTEXITCODE is not a reliable success signal here -- it can be left
    # over as $null from process start, and "$null -ne 0" is $true, which
    # would make this look like a failure even on success. get-love.ps1 sets
    # $ErrorActionPreference = "Stop" itself and throws on real failure,
    # which -- with this script's own "Stop" preference -- propagates as a
    # terminating error without reaching this check at all. So the only
    # thing worth verifying here is that it actually produced a usable path.
    $LovePath = & (Join-Path $PSScriptRoot "get-love.ps1")
    if (-not $LovePath) {
        Fail "tools/get-love.ps1 did not produce a love.exe path"
    }
    $LovePath = ($LovePath | Select-Object -Last 1).ToString().Trim()
}
if (-not (Test-Path $LovePath)) {
    Fail "LOVE runtime not found at '$LovePath'"
}

$loveDir = Split-Path -Parent $LovePath
$loveExe = $LovePath
$lovecExe = Join-Path $loveDir "lovec.exe"
if (-not (Test-Path $lovecExe)) {
    # lovec.exe (console-attached) is what prints to stdout on Windows; fall
    # back to love.exe if a runtime ever ships without it.
    $lovecExe = $loveExe
}
Write-Step "Using LOVE runtime at $loveDir"

# --- 2. Stage game source ----------------------------------------------------
Write-Step "Staging game source into $stageDir"
if (Test-Path $stageDir) { Remove-Item -Recurse -Force $stageDir }
New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

$excludeNames = @(".git", "tools", "tests", "docs", "dist", ".verify")
Get-ChildItem -Path $repoRoot -Force | ForEach-Object {
    if ($excludeNames -contains $_.Name) { return }
    if (-not $_.PSIsContainer -and $_.Extension -ieq ".md") { return }

    $destination = Join-Path $stageDir $_.Name
    if ($_.PSIsContainer) {
        Copy-Item -Path $_.FullName -Destination $destination -Recurse -Force
    } else {
        Copy-Item -Path $_.FullName -Destination $destination -Force
    }
}

# Belt-and-suspenders: strip any markdown that snuck in via a subdirectory.
Get-ChildItem -Path $stageDir -Recurse -Filter *.md -File -ErrorAction SilentlyContinue |
    Remove-Item -Force

if (-not (Test-Path (Join-Path $stageDir "main.lua"))) {
    Fail "main.lua missing from staged output -- the zip root would be unrunnable"
}

# --- 3. Zip to .love ----------------------------------------------------------
Write-Step "Zipping staged source to $loveFile"
if (Test-Path $loveFile) { Remove-Item -Force $loveFile }

Add-Type -AssemblyName System.IO.Compression.FileSystem
# includeBaseDirectory: $false -- files land at the zip ROOT, not nested
# under a "_stage" folder. That nesting is the classic mistake that makes a
# .love file silently unrunnable.
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $stageDir, $loveFile,
    [System.IO.Compression.CompressionLevel]::Optimal, $false)

Remove-Item -Recurse -Force $stageDir

if (-not (Test-Path $loveFile)) {
    Fail "$loveFile was not created"
}

# --- 4. Verify the .love actually boots ---------------------------------------
Write-Step "Verifying $loveFile with --test"
& $lovecExe $loveFile --test
$testExitCode = $LASTEXITCODE
if ($testExitCode -ne 0) {
    Fail "'$lovecExe `"$loveFile`" --test' exited $testExitCode -- refusing to package a broken build"
}
Write-Step "Verification passed (exit 0)"

# --- 5. Fuse the Windows exe ---------------------------------------------------
Write-Step "Fusing Windows executable"
New-Item -ItemType Directory -Force -Path $win64Dir | Out-Null
if (Test-Path $fusedExe) { Remove-Item -Force $fusedExe }

# LOVE's documented Windows packaging step: a straight binary concatenation
# of love.exe and the .love archive produces a self-contained executable.
$copyCommand = "copy /b `"$loveExe`"+`"$loveFile`" `"$fusedExe`""
$proc = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", $copyCommand) `
    -NoNewWindow -Wait -PassThru
if ($proc.ExitCode -ne 0 -or -not (Test-Path $fusedExe)) {
    Fail "fusing $fusedExe failed (cmd exit $($proc.ExitCode))"
}

# --- 6. Copy LOVE runtime files alongside the exe ------------------------------
Write-Step "Copying LOVE runtime DLLs and license into $win64Dir"
Get-ChildItem -Path $loveDir -Filter *.dll -File | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $win64Dir -Force
}
$licenseFile = Join-Path $loveDir "license.txt"
if (Test-Path $licenseFile) {
    Copy-Item -Path $licenseFile -Destination $win64Dir -Force
} else {
    Write-Host "note: no license.txt found in $loveDir to copy" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "BUILD OK" -ForegroundColor Green
Write-Host "  .love : $loveFile"
Write-Host "  exe   : $fusedExe"
exit 0
