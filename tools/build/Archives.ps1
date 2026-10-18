function New-Iwd($Archive) {
    $destination = Join-Path $work ('output\' + $Archive.file)
    $zip = [IO.Compression.ZipFile]::Open($destination, [IO.Compression.ZipArchiveMode]::Create)
    $count = 0
    try {
        foreach ($file in (Get-MappedFiles $Archive.entries | Sort-Object Relative)) {
            $entry = $zip.CreateEntry($file.Relative.Replace('\', '/').ToLowerInvariant(), [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
            $inputStream = [IO.File]::OpenRead($file.Source)
            try {
                $outputStream = $entry.Open()
                try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose() }
            } finally { $inputStream.Dispose() }
            $count++
        }
    } finally { $zip.Dispose() }
    Write-Step 'IWD' ("{0}: {1} files, {2:N2} MB" -f $Archive.file, $count, ((Get-Item -LiteralPath $destination).Length / 1MB))
}

function Copy-Configurations {
    $copied = 0
    foreach ($file in Get-MappedFiles $project.looseConfigs) {
        $published = Join-Path $OutputDirectory $file.Relative
        if ((Test-Path -LiteralPath $published -PathType Leaf) -and (Get-FileDigest $file.Source) -eq (Get-FileDigest $published)) { continue }
        $destination = Join-Path $work ('output\' + $file.Relative)
        New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
        Copy-Item -LiteralPath $file.Source -Destination $destination
        $copied++
    }
    Write-Step 'CONFIG' ("{0} changed files staged" -f $copied)
}
