function Test-Manifest {
    $seen = @{}
    $scriptAssets = @{}
    $sources = @{}
    foreach ($file in Get-SourceFiles) {
        $key = $file.Relative.Replace('\', '/')
        if ($sources.ContainsKey($key)) { throw "Overlapping source roots: $key" }
        $sources[$key] = $file.Source
    }
    foreach ($line in Get-ManifestLines) {
        $line = ($line -split '//', 2)[0].Trim()
        if (!$line) { continue }
        $columns = $line.Split(',')
        if ($columns.Count -lt 2) { throw "Malformed manifest entry: $line" }
        $kind, $name = $columns[0].Trim(), $columns[1].Trim()
        Test-RelativeArtifact $name
        $key = "$kind,$name"
        if ($seen.ContainsKey($key)) { throw "Duplicate manifest asset: $key" }
        $seen[$key] = $true
        if ($kind -in @('rawfile', 'menufile', 'stringtable', 'xmodel')) {
            $relative = $name.Replace('\', '/')
            if ($kind -eq 'xmodel') { $relative = 'xmodel/' + $relative }
            if (!$sources.ContainsKey($relative) -and !(Test-Path -LiteralPath (Join-Path (Join-Path $GameRoot 'raw') $relative) -PathType Leaf)) {
                throw "Missing $kind input: $name (checked source roots and SDK raw)"
            }
        }
        if ($kind -eq 'rawfile' -and $name.EndsWith('.gsc')) { $scriptAssets[$name.Replace('\', '/')] = $true }
    }
    foreach ($name in $scriptAssets.Keys) {
        if (!$sources.ContainsKey($name)) { continue }
        $text = [IO.File]::ReadAllText($sources[$name])
        $code = [regex]::Replace($text, '//[^\r\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"', ' ')
        foreach ($dependency in [regex]::Matches($code, '#include\s+([\w\\/]+)\s*;|([\w\\/]+)::')) {
            $path = $dependency.Groups[1].Value
            if (!$path) { $path = $dependency.Groups[2].Value }
            $path = $path.Replace('\', '/') + '.gsc'
            if ($sources.ContainsKey($path) -and !$scriptAssets.ContainsKey($path)) { throw "$name references $path, missing from manifests" }
        }
    }
    # Validate the entire archive/config plan before creating any artifacts.
    $outputs = @{}
    foreach ($archive in $project.archives) {
        Test-RelativeArtifact $archive.file
        $entries = @{}
        foreach ($file in Get-MappedFiles $archive.entries) {
            Test-RelativeArtifact $file.Relative
            if ($entries.ContainsKey($file.Relative)) { throw "Duplicate archive path: $($file.Relative)" }
            $entries[$file.Relative] = $true
            if ($file.Relative.EndsWith('.iwi', [StringComparison]::OrdinalIgnoreCase)) { Test-IwiLoadBudget $file.Source }
            if ($file.Relative -match '(?i)(^|/)private(?:\.example)?\.cfg$') { throw 'Private configuration cannot be packaged in a client archive.' }
        }
        if ($outputs.ContainsKey($archive.file)) { throw "Duplicate output: $($archive.file)" }
        $outputs[$archive.file] = $true
    }
    foreach ($file in Get-MappedFiles $project.looseConfigs) {
        Test-RelativeArtifact $file.Relative
        if ($outputs.ContainsKey($file.Relative)) { throw "Duplicate output: $($file.Relative)" }
        $outputs[$file.Relative] = $true
    }
    Write-Step 'CHECK' ("{0} manifest assets; {1} scripts; {2} mapped source files" -f $seen.Count, $scriptAssets.Count, $sources.Count)
}
