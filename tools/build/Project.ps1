function Write-Step([string]$Label, [string]$Message) {
    Write-Host ('  [{0,-8}] ' -f $Label) -ForegroundColor Cyan -NoNewline
    Write-Host $Message
}

function Get-ProjectPath([string]$Relative) {
    if ([IO.Path]::IsPathRooted($Relative)) { throw "Project path must be relative: $Relative" }
    $path = [IO.Path]::GetFullPath((Join-Path $modRoot $Relative))
    if (!$path.StartsWith($modRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes project: $Relative" }
    return $path
}

function Get-ManifestLines {
    $directory = Get-ProjectPath $project.manifestDirectory
    $fragments = @(Get-ChildItem -LiteralPath $directory -Filter '*.csv' -File | Sort-Object Name)
    if (!$fragments.Count) { throw "No manifest fragments found in $directory" }
    foreach ($fragment in $fragments) { Get-Content -LiteralPath $fragment.FullName }
}

function Get-SourceFiles {
    foreach ($relative in $project.sourceRoots) {
        $sourceRoot = Get-ProjectPath $relative
        Get-ChildItem -LiteralPath $sourceRoot -File -Recurse | ForEach-Object {
            [PSCustomObject]@{ Source = $_.FullName; Relative = $_.FullName.Substring($sourceRoot.Length + 1) }
        }
    }
}

function Get-MappedFiles($Entries) {
    foreach ($entry in $Entries) {
        $source = Get-ProjectPath $entry.source
        $excluded = @{}
        if ($entry.PSObject.Properties['excludeList']) {
            foreach ($name in (Get-Content -LiteralPath (Get-ProjectPath $entry.excludeList) -Raw | ConvertFrom-Json)) {
                Test-RelativeArtifact $name
                $excluded[$name.Replace('\','/').ToLowerInvariant()] = $true
            }
        }
        if (!(Test-Path -LiteralPath $source)) {
            if ($entry.PSObject.Properties['optional'] -and $entry.optional) { continue }
            throw "Missing project input: $($entry.source)"
        }
        if (Test-Path -LiteralPath $source -PathType Container) {
            Get-ChildItem -LiteralPath $source -File -Recurse | ForEach-Object {
                $relative = $_.FullName.Substring($source.Length + 1).Replace('\', '/')
                if (!$excluded.ContainsKey($relative.ToLowerInvariant())) {
                    [PSCustomObject]@{ Source = $_.FullName; Relative = ($entry.path.TrimEnd('/') + '/' + $relative) }
                }
            }
        } else { [PSCustomObject]@{ Source = $source; Relative = $entry.path } }
    }
}

function Test-RelativeArtifact([string]$Name) {
    if ([IO.Path]::IsPathRooted($Name) -or $Name -match '(^|[\\/])\.\.([\\/]|$)') { throw "Invalid artifact path: $Name" }
}
