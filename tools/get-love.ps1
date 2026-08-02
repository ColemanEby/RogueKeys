<#
.SYNOPSIS
    Downloads a portable LOVE 11.5 runtime for running and testing RogueKeys.

.DESCRIPTION
    No installation and no admin rights required. The runtime is extracted next
    to this script under tools/.love/ and the path to love.exe is written to
    stdout so callers can capture it.

.EXAMPLE
    $love = & tools/get-love.ps1
    & $love . --test
#>
[CmdletBinding()]
param(
    [string]$Version = "11.5",
    [string]$Destination
)

$ErrorActionPreference = "Stop"

if (-not $Destination) {
    $Destination = Join-Path $PSScriptRoot ".love"
}

$folder = Join-Path $Destination "love-$Version-win64"
$exe = Join-Path $folder "love.exe"

if (Test-Path $exe) {
    Write-Output $exe
    exit 0
}

New-Item -ItemType Directory -Force -Path $Destination | Out-Null

$zip = Join-Path $Destination "love-$Version-win64.zip"
$url = "https://github.com/love2d/love/releases/download/$Version/love-$Version-win64.zip"

if (-not (Test-Path $zip)) {
    Write-Verbose "Downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
}

Expand-Archive -Path $zip -DestinationPath $Destination -Force

if (-not (Test-Path $exe)) {
    throw "love.exe not found at $exe after extraction"
}

Write-Output $exe
