#requires -Version 5.1
<#
.SYNOPSIS
Build ApX Deathrun using project.json, manifest fragments, and the CoD4 Mod Tools.
.EXAMPLE
.\tools\build.ps1 -Target All
.EXAMPLE
.\tools\build.ps1 -Target Check
#>
[CmdletBinding()]
param(
    [ValidateSet('All', 'Fastfile', 'Iwd', 'Check')][string]$Target = 'All',
    [string]$GameRoot,
    [string]$OutputDirectory,
    [ValidatePattern('^[a-z]+$')][string]$Language = 'english',
    [switch]$Force,
    [switch]$Pause
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$modRoot = [IO.Path]::GetFullPath((Join-Path $scriptDirectory '..'))
if (!$GameRoot) { $GameRoot = Join-Path $modRoot '..\..' }
if (!$OutputDirectory) { $OutputDirectory = Join-Path $modRoot 'dist' }
$GameRoot = [IO.Path]::GetFullPath($GameRoot)
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$work = $null
$mutex = $null
$locked = $false
$script:retainWork = $false
$exitCode = 0
$timer = [Diagnostics.Stopwatch]::StartNew()
foreach ($module in @('Project', 'Manifest', 'Cache', 'Shaders', 'Archives', 'Linker', 'Publish')) {
    . (Join-Path $scriptDirectory ('build\' + $module + '.ps1'))
}
$project = Get-Content -LiteralPath (Join-Path $modRoot 'project.json') -Raw | ConvertFrom-Json

try {
    Write-Host ''
    Write-Host '  APX / DEATHRUN' -ForegroundColor Yellow
    Write-Host ("  {0} | {1}" -f (Split-Path $modRoot -Leaf), $Target) -ForegroundColor DarkGray
    Write-Host ''
    if (!(Test-Path -LiteralPath $GameRoot -PathType Container)) { throw "Game root does not exist: $GameRoot" }
    foreach ($relative in @('src', 'assets', 'config', 'manifests', 'tools', 'build')) {
        $protected = Get-ProjectPath $relative
        if ($OutputDirectory -eq $protected -or $OutputDirectory.StartsWith($protected + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Output directory overlaps project inputs: $protected"
        }
    }
    foreach ($relative in @('raw', 'zone_source', 'bin')) {
        $protected = [IO.Path]::GetFullPath((Join-Path $GameRoot $relative))
        if ($OutputDirectory -eq $protected -or $OutputDirectory.StartsWith($protected + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Output directory overlaps SDK inputs: $protected"
        }
    }
    if ($OutputDirectory -eq $modRoot) { throw 'Output directory cannot be the project root.' }
    Test-Manifest
    if ($Target -ne 'Check') {
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $hashProvider = [Security.Cryptography.SHA256]::Create()
        try { $key = [BitConverter]::ToString($hashProvider.ComputeHash([Text.Encoding]::UTF8.GetBytes($GameRoot.ToLowerInvariant()))).Replace('-', '') }
        finally { $hashProvider.Dispose() }
        $mutex = [Threading.Mutex]::new($false, ('Local\ApXDeathrunSDK_' + $key))
        try { $locked = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked = $true }
        if (!$locked) { throw 'Another Deathrun build is using this SDK. Wait for it to finish.' }
        New-Item -ItemType Directory -Path (Join-Path $modRoot 'build\tmp') -Force | Out-Null
        $work = Join-Path $modRoot ('build\tmp\' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $work 'output') -Force | Out-Null
        $script:retainWork = $false
        Initialize-BuildCache
        if ($Target -in @('All','Fastfile')) { Invoke-ProjectShaders }
        if ($Target -in @('All', 'Iwd')) {
            foreach ($archive in $project.archives) {
                $digest = Get-InputDigest @(Get-MappedFiles $archive.entries) $archive.file
                if (!(Test-ArtifactCurrent $archive.file $digest)) { New-Iwd $archive }
            }
        }
        if ($Target -in @('All', 'Fastfile')) {
            if (!(Test-ArtifactCurrent 'mod.ff' (Get-FastfileDigest))) { Build-Fastfile }
        }
        Copy-Configurations
        Publish-Outputs
        Save-BuildCache
        Write-Step 'OUTPUT' $OutputDirectory
    }
    Write-Host ("`n  Completed in {0:N1}s.`n" -f $timer.Elapsed.TotalSeconds) -ForegroundColor Green
} catch {
    Write-Host ("`n  FAILED: {0}`n" -f $_.Exception.Message) -ForegroundColor Red
    $exitCode = 1
} finally {
    if ($work -and !$script:retainWork -and (Test-Path -LiteralPath $work)) {
        # Only remove a verified, generated workspace below this mod's build/tmp directory.
        $tempRoot = [IO.Path]::GetFullPath((Join-Path $modRoot 'build\tmp')) + '\'
        $resolvedWork = [IO.Path]::GetFullPath($work)
        if ($resolvedWork.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedWork -Recurse -Force
        }
    }
    if ($locked) { $mutex.ReleaseMutex() }
    if ($mutex) { $mutex.Dispose() }
    if ($Pause) { [void](Read-Host 'Press Enter to close') }
}
exit $exitCode
