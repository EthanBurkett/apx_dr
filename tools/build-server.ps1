#requires -Version 5.1
<# Build the pinned upstream Windows server with the reviewed ApX pool patch. #>
[CmdletBinding()]
param([string]$GameRoot, [switch]$Install)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!$GameRoot) { $GameRoot = [IO.Path]::GetFullPath((Join-Path $root '..\..')) }
$source = Join-Path $root 'build\cod4x-server-src'
$toolRoot = Join-Path $root 'build\server-toolchain'
$toolchain = Join-Path $toolRoot 'mingw32\bin'
$revision = 'ddd65fce1a1093017bad2dbb6840d75d11c0d56f'
$patch = Join-Path $root 'server\patches\asset-pools.patch'
$previousPath = $env:Path
function Install-ApxServer([string]$Binary) {
    if (!$Install) { return }
    $destination = Join-Path $GameRoot 'apx_cod4x_dedrun.exe'
    if ((Test-Path -LiteralPath $destination) -and (Get-FileHash $destination).Hash -eq (Get-FileHash $Binary).Hash) { return }
    try { Copy-Item -LiteralPath $Binary -Destination $destination -Force }
    catch [IO.IOException] {
        # Keep a running user's server alive; stage the replacement for restart.
        Copy-Item -LiteralPath $Binary -Destination (Join-Path $GameRoot 'apx_cod4x_dedrun.next.exe') -Force
        Write-Warning 'The installed server is running. The rebuilt executable is staged as apx_cod4x_dedrun.next.exe for the next restart.'
    }
}
try {
    New-Item -ItemType Directory -Path $toolRoot, (Join-Path $root 'build\logs'), (Join-Path $root 'server\bin') -Force | Out-Null
    if (!(Test-Path -LiteralPath $source)) {
        & git clone https://github.com/callofduty4x/CoD4x_Server.git $source
        if ($LASTEXITCODE) { throw 'Could not fetch upstream CoD4x source.' }
        & git -C $source checkout --detach $revision
        if ($LASTEXITCODE) { throw 'Could not check out pinned source.' }
    }
    if ((& git -C $source rev-parse HEAD).Trim() -ne $revision) { throw 'Server source differs from the pinned upstream revision.' }
    & git -C $source apply --reverse --check $patch 2>$null
    if ($LASTEXITCODE) {
        & git -C $source apply --check $patch
        if ($LASTEXITCODE) { throw 'Server patch conflicts with local source changes.' }
        & git -C $source apply $patch
        if ($LASTEXITCODE) { throw 'Could not apply the ApX asset pool patch.' }
    }
    if (!(Test-Path -LiteralPath (Join-Path $toolchain 'gcc.exe'))) {
        $archive = Join-Path $toolRoot 'mingw32.7z'
        $url = 'https://downloads.sourceforge.net/mingw-w64/i686-8.1.0-release-posix-dwarf-rt_v6-rev0.7z'
        if (!(Test-Path -LiteralPath $archive)) { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $archive }
        if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne 'ADB84B70094C0225DD30187FF995E311D19424B1EB8F60934C60E4903297F946') { throw 'Unexpected portable compiler archive checksum.' }
        & (Join-Path $env:SystemRoot 'System32\tar.exe') -xf $archive -C $toolRoot
        if ($LASTEXITCODE) { throw 'Could not extract the portable compiler.' }
    }
    $nasm = Get-Command nasm.exe -ErrorAction Stop
    $output = Join-Path $root 'server\bin\apx_cod4x_dedrun.exe'
    $sourceZip = Join-Path $root 'server\apx-cod4x-source.zip'
    $record = Join-Path $root 'server\build.json'
    $untracked = @(& git -C $source ls-files --others --exclude-standard | ForEach-Object {
        if (Test-Path -LiteralPath (Join-Path $source $_) -PathType Leaf) { $_ + ':' + (Get-FileHash (Join-Path $source $_)).Hash }
    })
    $signature = @($revision, (Get-FileHash $patch).Hash, (Get-FileHash $PSCommandPath).Hash,
        (Get-FileHash (Join-Path $toolchain 'gcc.exe')).Hash, (Get-FileHash $nasm.Source).Hash,
        ((& git -C $source diff --binary HEAD) -join "`n"), ($untracked -join "`n")) -join "`n"
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $inputHash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($signature))).Replace('-','') }
    finally { $sha.Dispose() }
    if ((Test-Path -LiteralPath $record) -and (Test-Path -LiteralPath $output) -and (Test-Path -LiteralPath $sourceZip)) {
        $saved = Get-Content -LiteralPath $record -Raw | ConvertFrom-Json
        if ($saved.PSObject.Properties.Name -contains 'inputSHA256' -and $saved.inputSHA256 -eq $inputHash -and
            $saved.executableSHA256 -eq (Get-FileHash $output).Hash -and $saved.sourceSHA256 -eq (Get-FileHash $sourceZip).Hash) {
            Install-ApxServer $output
            Write-Host 'SKIP: custom server and source bundle unchanged.' -ForegroundColor Green
            return
        }
    }
    $env:Path = $toolchain + ';' + (Split-Path $nasm.Source) + ';' + $env:SystemRoot + '\System32;' + $env:Path
    Push-Location $source
    try {
        & mingw32-make.exe -j4 mbedtls tomcrypt SHELL=cmd.exe MAKE=mingw32-make.exe *> (Join-Path $root 'build\logs\server-libraries.log')
        if ($LASTEXITCODE) { throw 'Server support library build failed; see build/logs/server-libraries.log.' }
        & mingw32-make.exe -j4 bin/apx_cod4x_dedrun.exe TARGETNAME=apx_cod4x_dedrun BUILD_BRANCH=apx_dr SHELL=cmd.exe MAKE=mingw32-make.exe *> (Join-Path $root 'build\logs\server-compile.log')
        if ($LASTEXITCODE) { throw 'Server compilation failed; see build/logs/server-compile.log.' }
    } finally { Pop-Location }
    Copy-Item -LiteralPath (Join-Path $source 'bin\apx_cod4x_dedrun.exe') -Destination $output -Force
    $metadata = [ordered]@{ upstream = 'https://github.com/callofduty4x/CoD4x_Server'; revision = $revision; patchSHA256 = (Get-FileHash $patch).Hash; executableSHA256 = (Get-FileHash $output).Hash; pools = @{ weapon = 512; xmodel = 2048; material = 4096; image = 4096; fx = 1024; loaded_sound = 4096 } }
    # Supply the complete corresponding source, including modified files and license.
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $temporary = Join-Path $root 'build\apx-cod4x-source.zip'
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
    $zip = [IO.Compression.ZipFile]::Open($temporary, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($relative in (& git -C $source ls-files --cached --others --exclude-standard | Sort-Object -Unique)) {
            # Optional plugin gitlinks are not part of this server executable.
            if (!(Test-Path -LiteralPath (Join-Path $source $relative) -PathType Leaf)) { continue }
            $entry = $zip.CreateEntry($relative, [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::new(1980,1,1,0,0,0,[TimeSpan]::Zero)
            $inputStream = [IO.File]::OpenRead((Join-Path $source $relative))
            $outputStream = $entry.Open()
            try { $inputStream.CopyTo($outputStream) } finally { $inputStream.Dispose(); $outputStream.Dispose() }
        }
        $entry = $zip.CreateEntry('APX_BUILD.md')
        $stream = $entry.Open()
        $writer = [IO.StreamWriter]::new($stream)
        try { $writer.Write("ApX source revision: $revision`nModified asset pools are in src/db_load.cpp.`nUse i686 GCC 8.1 and NASM on Windows. Build support libraries with mingw32-make mbedtls tomcrypt, then build bin/cod4x18_dedrun.exe with mingw32-make bin/cod4x18_dedrun.exe. Upstream License.md applies. Optional plugin submodules are not used by this executable.`n") }
        finally { $writer.Dispose() }
    } finally { $zip.Dispose() }
    Move-Item -LiteralPath $temporary -Destination $sourceZip -Force
    Copy-Item -LiteralPath (Join-Path $source 'License.md') -Destination (Join-Path $root 'server\LICENSE.md') -Force
    $metadata.inputSHA256 = $inputHash
    $metadata.sourceSHA256 = (Get-FileHash $sourceZip).Hash
    [IO.File]::WriteAllText($record, ($metadata | ConvertTo-Json -Depth 4))
    Install-ApxServer $output
    Write-Host "Built ApX CoD4x server: $output" -ForegroundColor Green
} finally { $env:Path = $previousPath }
