#requires -Version 5.1
param([string]$SdkArchive = 'build/ci-sdk.zip', [switch]$ExpandedSdk, [string]$OutputDirectory, [string]$Python = 'python')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sdk = Join-Path $root 'build/ci-sdk/game'
if (!$OutputDirectory) { $OutputDirectory = Join-Path $root 'dist' }
if (!$ExpandedSdk) {
    if (Test-Path -LiteralPath $sdk) { throw 'Use a fresh CI checkout; SDK destination already exists.' }
    & $Python -m zipfile -e $SdkArchive $sdk
    if ($LASTEXITCODE -ne 0) { throw 'SDK extraction failed.' }
}
foreach ($relative in @('zone_source/english/assetlist','zone_source/english/assetinfo','zone/english')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $sdk $relative) | Out-Null
}
& (Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe') -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build.ps1') -GameRoot $sdk -OutputDirectory $OutputDirectory
if ($LASTEXITCODE -ne 0) { throw 'SDK build failed.' }
