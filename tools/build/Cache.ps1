# Incremental state is committed only after successful publication. Project inputs
# and outputs use SHA-256; SDK inputs use size/time metadata, excluding overlays.
function Get-TextDigest([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Get-FileDigest([string]$Path, [switch]$Refresh) {
    if (!$script:fileDigests) { $script:fileDigests = @{} }
    if (!$Refresh -and $script:fileDigests.ContainsKey($Path)) { return $script:fileDigests[$Path] }
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try { $result = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $stream.Dispose(); $sha.Dispose() }
    $script:fileDigests[$Path] = $result
    return $result
}

function Initialize-BuildCache {
    $script:fileDigests = @{}
    $script:cacheRecords = @{}
    $script:pendingRecords = @{}
    $key = Get-TextDigest ($OutputDirectory.ToLowerInvariant() + '|' + $GameRoot.ToLowerInvariant() + '|' + $Language)
    $script:cachePath = Join-Path $modRoot ('build\state\' + $key + '.json')
    if (Test-Path -LiteralPath $script:cachePath) {
        try {
            $saved = Get-Content -LiteralPath $script:cachePath -Raw | ConvertFrom-Json
            foreach ($entry in $saved.PSObject.Properties) { $script:cacheRecords[$entry.Name] = $entry.Value }
        } catch { Write-Warning 'Incremental state could not be read; requested artifacts will be rebuilt.' }
    }
    $script:toolSignature = Get-TextDigest ((@(Get-ChildItem -LiteralPath (Join-Path $modRoot 'tools\build') -File | Sort-Object Name | ForEach-Object { $_.Name + ':' + (Get-FileDigest $_.FullName) }) +
        (Get-FileDigest (Join-Path $modRoot 'tools\build.ps1')) + (Get-FileDigest (Join-Path $modRoot 'project.json'))) -join "`n")
}

function Get-InputDigest($Files, [string]$Metadata) {
    $lines = [Text.StringBuilder]::new()
    [void]$lines.AppendLine($script:toolSignature)
    [void]$lines.AppendLine($Metadata)
    foreach ($file in @($Files | Sort-Object Relative)) {
        [void]$lines.AppendLine($file.Relative.Replace('\', '/').ToLowerInvariant() + ':' + (Get-FileDigest $file.Source))
    }
    return Get-TextDigest $lines.ToString()
}

function Get-FastfileDigest {
    $sources = @(Get-SourceFiles)
    $overlays = @{}
    foreach ($file in $sources) { $overlays[$file.Relative.ToLowerInvariant()] = $true }
    $metadata = [Text.StringBuilder]::new()
    [void]$metadata.AppendLine($Language)
    [void]$metadata.AppendLine((Get-ManifestLines) -join "`n")
    $linker = Join-Path $GameRoot 'bin\linker_pc.exe'
    if (Test-Path -LiteralPath $linker -PathType Leaf) { [void]$metadata.AppendLine((Get-FileDigest $linker)) }
    # CoD4's binary asset dependencies are not fully exposed by the linker. Track
    # the SDK raw namespace conservatively so stock dependencies cannot change unnoticed.
    $raw = Join-Path $GameRoot 'raw'
    if (Test-Path -LiteralPath $raw -PathType Container) {
        foreach ($path in [IO.Directory]::EnumerateFiles($raw, '*', [IO.SearchOption]::AllDirectories) | Sort-Object) {
            $relative = $path.Substring($raw.Length + 1).ToLowerInvariant()
            if ($overlays.ContainsKey($relative)) { continue }
            $info = [IO.FileInfo]::new($path)
            [void]$metadata.AppendLine($relative + ':' + $info.Length + ':' + $info.LastWriteTimeUtc.Ticks)
        }
    }
    return Get-InputDigest $sources $metadata.ToString()
}

function Test-ArtifactCurrent([string]$Name, [string]$Digest) {
    $script:pendingRecords[$Name] = $Digest
    $path = Join-Path $OutputDirectory $Name
    if ($Force -or !$script:cacheRecords.ContainsKey($Name) -or !(Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    $record = $script:cacheRecords[$Name]
    if ($record.Input -ne $Digest -or $record.Output -ne (Get-FileDigest $path)) { return $false }
    Write-Step 'SKIP' ("{0}: unchanged" -f $Name)
    return $true
}

function Save-BuildCache {
    foreach ($name in $script:pendingRecords.Keys) {
        $script:cacheRecords[$name] = @{ Input = $script:pendingRecords[$name]; Output = (Get-FileDigest (Join-Path $OutputDirectory $name) -Refresh) }
    }
    try {
        New-Item -ItemType Directory -Path (Split-Path $script:cachePath) -Force | Out-Null
        $temporary = Join-Path $work 'cache.json'
        [IO.File]::WriteAllText($temporary, ($script:cacheRecords | ConvertTo-Json -Depth 4))
        if (Test-Path -LiteralPath $script:cachePath) { [IO.File]::Replace($temporary, $script:cachePath, (Join-Path $work 'previous-cache.json')) }
        else { [IO.File]::Move($temporary, $script:cachePath) }
    } catch { Write-Warning "Build succeeded, but incremental state could not be saved: $_" }
}
