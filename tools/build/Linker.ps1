function New-ContentLinker([string]$Original) {
    # The retail SDK reserves virtual stream address ranges, not engine pools.
    # Its vertex/index ranges (32/8 MiB) cannot serialize the expanded catalog.
    # Only a verified sibling copy is adjusted; the installed executable stays intact.
    $expected = '7A3BD700EB4E21F5DAFD94B25F54600E6963C15D4CEC2DDEF76D3661AE524C31'
    if ((Get-FileHash -LiteralPath $Original -Algorithm SHA256).Hash -ne $expected) {
        throw 'The large-content linker profile requires the verified CoD4 SDK linker. No executable was modified.'
    }
    $bytes = [IO.File]::ReadAllBytes($Original)
    if ([BitConverter]::ToUInt32($bytes, 0x110a14) -ne 0x02000000 -or
        [BitConverter]::ToUInt32($bytes, 0x110a18) -ne 0x00800000) { throw 'Unexpected linker stream layout.' }
    [Array]::Copy([BitConverter]::GetBytes([uint32]0x08000000), 0, $bytes, 0x110a14, 4)
    [Array]::Copy([BitConverter]::GetBytes([uint32]0x04000000), 0, $bytes, 0x110a18, 4)
    $copy = Join-Path (Split-Path $Original) ('apx_linker_' + [Guid]::NewGuid().ToString('N') + '.exe')
    [IO.File]::WriteAllBytes($copy, $bytes)
    Write-Step 'LINK SDK' 'Private tool copy: vertex stream 128 MiB; index stream 64 MiB.'
    return $copy
}

function Build-Fastfile {
    $linker = Join-Path $GameRoot 'bin\linker_pc.exe'
    if (!(Test-Path -LiteralPath $linker -PathType Leaf)) { throw "CoD4 Mod Tools linker not found: $linker" }
    foreach ($required in @('raw', 'zone_source')) {
        if (!(Test-Path -LiteralPath (Join-Path $GameRoot $required) -PathType Container)) {
            throw "CoD4 Mod Tools directory missing: $required (GameRoot: $GameRoot)"
        }
    }
    # Build the conventional mod zone. Snapshot shared zone files as well as
    # raw inputs, and restore both afterwards.
    $zoneName = 'mod'
    $zoneSource = Join-Path $GameRoot "zone_source\$zoneName.csv"
    $zoneOutput = Join-Path $GameRoot "zone\$Language\$zoneName.ff"
    $log = Join-Path $modRoot ('build\logs\linker-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.log')
    New-Item -ItemType Directory -Path (Split-Path $log) -Force | Out-Null
    $staged = [Collections.Generic.List[object]]::new()
    $privateLinker = $null
    $restoreFailed = $false
    $zoneBackups = @{}
    foreach ($path in @($zoneSource, $zoneOutput)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $backup = Join-Path $work ('sdk-zone-backup\' + [IO.Path]::GetFileName($path))
            New-Item -ItemType Directory -Path (Split-Path $backup) -Force | Out-Null
            Copy-Item -LiteralPath $path -Destination $backup
            $zoneBackups[$path] = $backup
        }
    }
    try {
        if ($project.PSObject.Properties.Name -contains 'linkerMemoryProfile') {
            if ($project.linkerMemoryProfile -ne 'cod4-sdk-large-content-v1') { throw 'Unknown linker memory profile.' }
            $privateLinker = New-ContentLinker $linker
            $linker = $privateLinker
        }
        foreach ($file in Get-SourceFiles) {
            $destination = Join-Path (Join-Path $GameRoot 'raw') $file.Relative
            $backup = $null
            if (Test-Path -LiteralPath $destination -PathType Leaf) {
                if ((Get-FileHash -LiteralPath $file.Source).Hash -eq (Get-FileHash -LiteralPath $destination).Hash) { continue }
                $backup = Join-Path $work ('sdk-backup\' + $file.Relative)
                New-Item -ItemType Directory -Path (Split-Path $backup) -Force | Out-Null
                Copy-Item -LiteralPath $destination -Destination $backup
            }
            $staged.Add([PSCustomObject]@{ Destination = $destination; Backup = $backup })
            New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
            Copy-Item -LiteralPath $file.Source -Destination $destination -Force
        }
        [IO.File]::WriteAllLines($zoneSource, [string[]]@(Get-ManifestLines), [Text.Encoding]::Default)
        if (Test-Path -LiteralPath $zoneOutput) { Remove-Item -LiteralPath $zoneOutput -Force }
        Write-Step 'LINK' ("{0} changed source files staged; full log: {1}" -f $staged.Count, $log)
        $process = [Diagnostics.Process]::new()
        $process.StartInfo.FileName = $linker
        $process.StartInfo.Arguments = "-language $Language -compress -cleanup $zoneName"
        $process.StartInfo.WorkingDirectory = Join-Path $GameRoot 'bin'
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true
        $process.StartInfo.RedirectStandardInput = $true
        try {
            [void]$process.Start()
            $process.StandardInput.Close()
            # Drain both pipes while the linker runs. SDK failures can otherwise
            # continue into compression and open a blocking assertion dialog.
            [IO.File]::WriteAllText($log, '')
            $readers = @(
                [PSCustomObject]@{ Reader = $process.StandardOutput; Pending = $process.StandardOutput.ReadLineAsync() },
                [PSCustomObject]@{ Reader = $process.StandardError; Pending = $process.StandardError.ReadLineAsync() }
            )
            $deadline = [Diagnostics.Stopwatch]::StartNew()
            $timedOut = $false
            while (!$process.HasExited -or @($readers | Where-Object { $null -ne $_.Pending }).Count) {
                foreach ($reader in $readers) {
                    while ($null -ne $reader.Pending -and $reader.Pending.IsCompleted) {
                        $line = $reader.Pending.GetAwaiter().GetResult()
                        if ($null -eq $line) { $reader.Pending = $null; break }
                        [IO.File]::AppendAllText($log, $line + [Environment]::NewLine)
                        if ($line -match '^\s*(?:Menu load error:|ERROR:|ERROR\s*\(|FATAL(?:\s+ERROR)?\b|UNRECOVERABLE ERROR)') {
                            if (!$process.HasExited) { $process.Kill() }
                        }
                        $reader.Pending = $reader.Reader.ReadLineAsync()
                    }
                }
                if (!$process.HasExited -and $deadline.Elapsed.TotalSeconds -ge 300) {
                    $timedOut = $true
                    $process.Kill()
                }
                if (!$process.HasExited) { Start-Sleep -Milliseconds 20 }
            }
            $process.WaitForExit()
            $linkerExit = $process.ExitCode
            if ($timedOut) { throw "Linker exceeded five minutes. See $log" }
        } finally { $process.Dispose() }
        $logText = [IO.File]::ReadAllText($log)
        if ($linkerExit -ne 0 -or !(Test-Path -LiteralPath $zoneOutput -PathType Leaf) -or
            (Get-Item -LiteralPath $zoneOutput).Length -eq 0 -or
            $logText -match '(?im)^\s*(?:Menu load error:|ERROR:|ERROR\s*\(|FATAL(?:\s+ERROR)?\b|UNRECOVERABLE ERROR)') {
            Get-Content -LiteralPath $log -Tail 25 | ForEach-Object { Write-Host "    $_" }
            throw "Linker failed (exit $linkerExit). Previous build outputs are preserved. See $log"
        }
        if ($logText -match '(?im)\bwarning\b|could not|couldn.t|missing|not found') {
            Write-Warning "Linker diagnostics need review: $log"
        }
        Copy-Item -LiteralPath $zoneOutput -Destination (Join-Path $work 'output\mod.ff')
        Write-Step 'FASTFILE' ("mod.ff: {0:N2} MB" -f ((Get-Item -LiteralPath $zoneOutput).Length / 1MB))
    } finally {
        if ($privateLinker -and (Test-Path -LiteralPath $privateLinker)) { Remove-Item -LiteralPath $privateLinker -Force }
        foreach ($file in $staged) {
            try {
                if ($file.Backup) { Copy-Item -LiteralPath $file.Backup -Destination $file.Destination -Force }
                else { Remove-Item -LiteralPath $file.Destination -Force }
            } catch { $restoreFailed = $true; Write-Warning "SDK restore failed for $($file.Destination): $_" }
        }
        foreach ($temporary in @($zoneSource, $zoneOutput)) {
            try {
                if ($zoneBackups.ContainsKey($temporary)) { Copy-Item -LiteralPath $zoneBackups[$temporary] -Destination $temporary -Force }
                elseif (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
            } catch { $restoreFailed = $true; Write-Warning "SDK zone restoration failed for $temporary : $_" }
        }
        if ($restoreFailed) {
            $script:retainWork = $true
            throw "SDK restoration incomplete. Recovery files retained in $work"
        }
    }
}
