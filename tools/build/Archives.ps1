function Test-IwiLoadBudget($Path) {
    # The official client's Image_LoadFromFileWithReader uses a fixed 6 MiB
    # scratch buffer. This is independent of total VRAM and asset pool sizes.
    $header = [byte[]]::new(28)
    $stream = [IO.File]::OpenRead($Path)
    try { $length = $stream.Length; $read = $stream.Read($header, 0, 28) } finally { $stream.Dispose() }
    if ($read -ne 28 -or [Text.Encoding]::ASCII.GetString($header, 0, 3) -ne 'IWi' -or $header[3] -ne 6) {
        throw "Invalid CoD4 IWI header: $Path"
    }
    $stored = [BitConverter]::ToUInt32($header, 12)
    if ($stored -ne $length -or $stored -le 28) { throw "Invalid IWI payload length: $Path" }
    $scratch = ([long]$stored - 28 + 3) -band (-bnot [long]3)
    $width = [BitConverter]::ToUInt16($header, 6)
    $height = [BitConverter]::ToUInt16($header, 8)
    $depth = [BitConverter]::ToUInt16($header, 10)
    $channels = 0
    # BGR expands to BGRA; wavelet formats additionally decode their top mip.
    switch ($header[4]) { 2 { $channels = 4 }; 6 { $channels = 4 }; 7 { $channels = 4 }; 8 { $channels = 2 }; 9 { $channels = 1 }; 10 { $channels = 1 } }
    $faces = if ($header[5] -band 4) { 6 } else { 1 }
    $scratch += [long]$width * $height * $depth * $channels * $faces
    if ($scratch -gt 6MB) {
        throw ('IWI image-load scratch budget exceeded: {0} needs {1:N2} MiB; client limit is 6 MiB. Split the image into smaller pages.' -f $Path, ($scratch / 1MB))
    }
}

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
