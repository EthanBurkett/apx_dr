#requires -Version 5.1
<#
.SYNOPSIS
Launch the built mod as a client or dedicated CoD4x server.
.EXAMPLE
.\tools\launch.ps1 -Address 127.0.0.1:28960
.EXAMPLE
.\tools\launch.ps1 -Mode Server -Map mp_dr_lithium -Port 28961
#>
[CmdletBinding()]
param(
    [ValidateSet('Client', 'Server')][string]$Mode = 'Client',
    [string]$GameRoot,
    [string]$ModDirectory,
    [string]$Executable,
    [ValidatePattern('^[a-zA-Z0-9.:-]+$')][string]$Address = 'localhost',
    [ValidatePattern('^mp_[a-zA-Z0-9_]+$')][string]$Map = 'mp_dr_lithium',
    [ValidateRange(1, 65535)][int]$Port = 28960,
    [ValidateSet(1, 2)][int]$Dedicated = 2,
    [ValidatePattern('^[a-zA-Z0-9_-]+\.cfg$')][string]$ServerConfig = 'server.cfg'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    $sourceRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..'))
    if (!$GameRoot) { $GameRoot = Join-Path $sourceRoot '..\..' }
    if (!$ModDirectory) { $ModDirectory = Join-Path $sourceRoot 'dist' }
    $GameRoot = [IO.Path]::GetFullPath($GameRoot)
    if (!$Executable) {
        if ($Mode -eq 'Server') { $Executable = 'apx_cod4x_dedrun.exe' }
        else { $Executable = 'iw3mp.exe' }
    }
    $ModDirectory = [IO.Path]::GetFullPath($ModDirectory)
    if (!$ModDirectory.StartsWith($GameRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The mod directory must be inside the game directory so fs_game can resolve it.'
    }
    $fsGame = $ModDirectory.Substring($GameRoot.Length + 1).Replace('\', '/')
    $project = Get-Content -LiteralPath (Join-Path $sourceRoot 'project.json') -Raw | ConvertFrom-Json
    foreach ($required in (@('mod.ff') + @($project.archives | ForEach-Object { $_.file }))) {
        if (!(Test-Path -LiteralPath (Join-Path $ModDirectory $required) -PathType Leaf)) {
            throw "Build output missing: $required. Run tools/build.ps1 first, or pass -ModDirectory for an installed build."
        }
    }
    $gameExecutable = Join-Path $GameRoot $Executable
    if (!(Test-Path -LiteralPath $gameExecutable -PathType Leaf)) {
        throw "Game executable not found: $gameExecutable. Use -Executable for your Windows CoD4x binary. For Linux cod4x_dedrun, see README.md."
    }
    $arguments = @('+set', 'fs_game', $fsGame)
    if ($Mode -eq 'Client') {
        # The mod's menu loads before a server can advertise its asset budget.
        $arguments = @('+set', 'r_xassetnum', 'xmodel=2048 image=4096 fx=1024 loaded_sound=4096') + $arguments
        $arguments += @('+connect', $Address)
    }
    if ($Mode -eq 'Server') {
        if (!(Test-Path -LiteralPath (Join-Path $ModDirectory $ServerConfig) -PathType Leaf)) {
            throw "Server config missing: $ServerConfig"
        }
        $arguments += @('+set', 'dedicated', "$Dedicated", '+set', 'net_port', "$Port",
            '+set', 'g_gametype', 'deathrun', '+exec', $ServerConfig, '+map', $Map, '+set', 'g_speed', '210')
    }
    Write-Host ("Launching {0}: {1}" -f $Mode.ToLowerInvariant(), $fsGame) -ForegroundColor Cyan
    Push-Location $GameRoot
    try { & $gameExecutable @arguments; $result = $LASTEXITCODE } finally { Pop-Location }
    exit $result
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
