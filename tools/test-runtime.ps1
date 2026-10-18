#requires -Version 5.1
<#
.SYNOPSIS
Run a bounded, loopback-only CoD4x server smoke test against an existing build.
.DESCRIPTION
Uses isolated logs, loads gameplay defaults without private/server settings,
checks server status over UDP, and always stops its own test process.
This verifies loading and idle initialization, not multiplayer gameplay.
#>
[CmdletBinding()]
param(
    [string]$GameRoot,
    [string]$ModDirectory,
    [ValidatePattern('^[a-zA-Z0-9_]+$')][string]$GameType = 'deathrun',
    [string]$RequiredMarker,
    [switch]$AssetUsage,
    [switch]$ClientBudget,
    [string]$Executable = 'apx_cod4x_dedrun.exe',
    [ValidatePattern('^mp_[a-zA-Z0-9_]+$')][string]$Map = 'mp_deathrun_long',
    [ValidateRange(1024, 65535)][int]$Port = 28991,
    [ValidateRange(10, 120)][int]$Duration = 20
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$modRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..'))
if (!$GameRoot) { $GameRoot = Join-Path $modRoot '..\..' }
$GameRoot = [IO.Path]::GetFullPath($GameRoot)
if (!$ModDirectory) { $ModDirectory = Join-Path $modRoot 'dist' }
$output = [IO.Path]::GetFullPath($ModDirectory)
$process = $null
$socket = $null
$exitCode = 1
$smoke = Join-Path $modRoot ('build\runtime-tests\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + $Map)
try {
    if (!$output.StartsWith($GameRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'The build must be inside the game root.' }
    foreach ($path in @((Join-Path $GameRoot $Executable), (Join-Path $output 'mod.ff'))) {
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file missing: $path" }
    }
    if ($smoke.Contains('"')) { throw 'The test log path cannot contain a quote.' }
    $modPath = $output.Substring($GameRoot.Length + 1).Replace('\', '/')
    if ($modPath.Length -gt 63) { throw "fs_game exceeds the engine's 63-character path limit. Use a shorter test output path: $modPath" }
    # Refuse to reuse an occupied UDP port rather than interrogating another server.
    $probe = [Net.Sockets.UdpClient]::new()
    try { $probe.Client.Bind([Net.IPEndPoint]::new([Net.IPAddress]::Loopback, $Port)) }
    finally { $probe.Dispose() }
    New-Item -ItemType Directory -Path $smoke -Force | Out-Null
    # Startup +set arguments are applied before +exec, regardless of their
    # textual order. Override core.cfg's gametype through the command buffer.
    $runtimeConfig = Join-Path (Join-Path $smoke $modPath) 'apx_runtime.cfg'
    New-Item -ItemType Directory -Path (Split-Path $runtimeConfig) -Force | Out-Null
    [IO.File]::WriteAllText($runtimeConfig, "set g_gametype $GameType`n")
    $arguments = '+set dedicated 1 +set fs_homepath "' + $smoke + '" +set fs_game ' + $modPath +
        ' +set developer 1 +set developer_script 1 +set logfile 2 +set g_gametype deathrun' +
        ' +exec deathrun.cfg +exec dr_songs.cfg +exec apx_runtime.cfg' +
        ' +set net_ip 127.0.0.1 +set net_port ' + $Port + ' +map ' + $Map
    if ($AssetUsage -or $ClientBudget) { $arguments += ' +XAssetUsage' }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = Join-Path $GameRoot $Executable
    $process.StartInfo.WorkingDirectory = $GameRoot
    $process.StartInfo.Arguments = $arguments
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    [void]$process.Start()
    $socket = [Net.Sockets.UdpClient]::new()
    $socket.Client.ReceiveTimeout = 250
    $socket.Connect('127.0.0.1', $Port)
    $request = [byte[]]@(255, 255, 255, 255) + [Text.Encoding]::ASCII.GetBytes('getstatus apx-smoke')
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $log = Join-Path $smoke 'main\qconsole.log'
    $ready = $false
    $initialized = $false
    $markerFound = !$RequiredMarker
    while ($timer.Elapsed.TotalSeconds -lt $Duration) {
        if ($process.HasExited) { throw "Server exited early with code $($process.ExitCode). See $log" }
        # Newer native servers reopen the console under fs_game after FS restart.
        $modLog = Join-Path (Join-Path $smoke $modPath) 'qconsole.log'
        if (Test-Path -LiteralPath $modLog) { $log = $modLog }
        if (Test-Path -LiteralPath $log) {
            $reader = [IO.StreamReader]::new([IO.FileStream]::new($log, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite))
            try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
            $initialized = $text.Contains('Calculate referenced files checksums')
            if ($RequiredMarker -and $text.Contains($RequiredMarker)) { $markerFound = $true }
            if ($text -match '(?i)script (?:compile|runtime) error|server fatal|exceeded (?:maximum number|limit of)|terminal script error') {
                throw "Server reported a fatal script/load error. See $log"
            }
        }
        [void]$socket.Send($request, $request.Length)
        try {
            $remote = [Net.IPEndPoint]::new([Net.IPAddress]::Any, 0)
            $reply = [Text.Encoding]::ASCII.GetString($socket.Receive([ref]$remote))
            if (($reply.Contains('\g_gametype\' + $GameType + '\') -or $reply.Contains('\g_gametype\deathrun\')) -and $reply.Contains('\mapname\' + $Map + '\')) { $ready = $true }
        } catch [Net.Sockets.SocketException] { }
        Start-Sleep -Milliseconds 250
    }
    if (!$ready) { throw "No Deathrun status reply received. See $log" }
    if (!$initialized) { throw "Initialization did not complete. See $log" }
    if (!$markerFound) { throw "Required runtime assertion marker missing: $RequiredMarker. See $log" }
    if ($ClientBudget) {
        $profile = Get-Content -LiteralPath (Join-Path $modRoot 'ui\content_profile.json') -Raw | ConvertFrom-Json
        $usage = @{}
        foreach ($match in [regex]::Matches($text, '(?m)^([a-z_]+)\s+(\d+)\s+(\d+)\s*$')) {
            $usage[$match.Groups[1].Value] = [int]$match.Groups[2].Value
        }
        foreach ($budget in $profile.max_usage.PSObject.Properties) {
            if (!$usage.ContainsKey($budget.Name)) { throw "Missing asset usage counter: $($budget.Name). See $log" }
            if ($usage[$budget.Name] -gt $budget.Value) { throw "Official-client budget exceeded: $($budget.Name) uses $($usage[$budget.Name]), target $($budget.Value). See $log" }
            Write-Host ("  {0}: {1} used / {2} target / {3} client limit" -f $budget.Name, $usage[$budget.Name], $budget.Value, $profile.client_limits.($budget.Name))
        }
    }
    Write-Host "PASS: $Map loaded and answered status during a $Duration-second CoD4x smoke test." -ForegroundColor Green
    Write-Host "Logs: $smoke"
    $exitCode = 0
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
} finally {
    if ($socket) { $socket.Dispose() }
    if ($process) {
        if (!$process.HasExited) { Stop-Process -Id $process.Id -Force; $process.WaitForExit() }
        $process.Dispose()
    }
}
exit $exitCode
