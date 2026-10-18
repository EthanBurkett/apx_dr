#requires -Version 5.1
<# Build a diagnostic server that counts the client's extra startup zones.
   Never installs or changes the playable server. Run build-server.ps1 first
   to prepare the pinned upstream source, reviewed pool patch and compiler. #>
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source=Join-Path $root 'build/cod4x-server-src'
if(!(Test-Path -LiteralPath $source)) { throw 'Run tools/build-server.ps1 to prepare the pinned server toolchain first.' }
if((& git -C $source rev-parse HEAD).Trim() -ne 'ddd65fce1a1093017bad2dbb6840d75d11c0d56f') { throw 'Unexpected upstream revision.' }
$file=Join-Path $source 'src/xassets.c'
$dbFile=Join-Path $source 'src/db_load.cpp'
$original=[IO.File]::ReadAllBytes($file)
$dbOriginal=[IO.File]::ReadAllBytes($dbFile)
$oldPath=$env:Path
$output=Join-Path $root 'build/client-audit'
New-Item -ItemType Directory -Path $output -Force | Out-Null
try {
    $text=[Text.Encoding]::UTF8.GetString($original)
    if(([regex]::Matches($text,'#ifndef DEDICATEDONLY')).Count -ne 2) { throw 'Unexpected startup-zone implementation.' }
    $text=$text.Replace('#ifndef DEDICATEDONLY','#if 1 /* ApX isolated client-zone budget diagnostic */')
    # Keep the diagnostic UI zone resident: the dedicated server has no renderer
    # allocation to release when its usual menu-unload path runs on map load.
    $text=$text.Replace('XZoneInfoStack[i].allocFlags = 8;','XZoneInfoStack[i].allocFlags = 0;')
    [IO.File]::WriteAllText($file,$text,[Text.UTF8Encoding]::new($false))
    # Extra menu records are needed only to enumerate both client startup zones.
    $dbText=[Text.Encoding]::UTF8.GetString($dbOriginal).Replace('g_poolSize[ASSET_TYPE_MENU] = 640;','g_poolSize[ASSET_TYPE_MENU] = 2048;')
    [IO.File]::WriteAllText($dbFile,$dbText,[Text.UTF8Encoding]::new($false))
    $env:Path=(Join-Path $root 'build/server-toolchain/mingw32/bin')+';'+$env:Path
    Push-Location $source
    try {
        & mingw32-make.exe -j4 bin/apx_poolaudit.exe TARGETNAME=apx_poolaudit BUILD_BRANCH=apx_asset_audit SHELL=cmd.exe MAKE=mingw32-make.exe *> (Join-Path $output 'compile.log')
        if($LASTEXITCODE) {throw 'Diagnostic server compile failed; see build/client-audit/compile.log'}
    } finally {Pop-Location}
    Copy-Item -LiteralPath (Join-Path $source 'bin/apx_poolaudit.exe') -Destination (Join-Path $output 'apx_poolaudit.exe')
    Write-Host 'Built build/client-audit/apx_poolaudit.exe. Playable server unchanged.'
} finally {
    # Restore bytes, with a fresh timestamp so normal builds recompile these
    # objects instead of accidentally reusing diagnostic startup-zone behavior.
    [IO.File]::WriteAllBytes($file,$original)
    [IO.File]::WriteAllBytes($dbFile,$dbOriginal)
    $env:Path=$oldPath
}
