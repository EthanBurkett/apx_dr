function Publish-Outputs {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $published = [Collections.Generic.List[object]]::new()
    $outputRoot = Join-Path $work 'output'
    try {
        $files = @(Get-ChildItem -LiteralPath $outputRoot -File -Recurse)
        foreach ($file in $files) {
            $relative = $file.FullName.Substring($outputRoot.Length + 1)
            $destination = Join-Path $OutputDirectory $relative
            $backup = $null
            if (Test-Path -LiteralPath $destination -PathType Leaf) {
                $backup = Join-Path $work ('previous-output\' + $relative)
                New-Item -ItemType Directory -Path (Split-Path $backup) -Force | Out-Null
                Copy-Item -LiteralPath $destination -Destination $backup
            }
            $published.Add([PSCustomObject]@{ Destination = $destination; Backup = $backup })
            New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
            Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
        }
        foreach ($relative in $project.obsoleteOutputs) {
            Test-RelativeArtifact $relative
            $destination = Join-Path $OutputDirectory $relative
            if (!(Test-Path -LiteralPath $destination -PathType Leaf)) { continue }
            $backup = Join-Path $work ('previous-output\' + $relative)
            New-Item -ItemType Directory -Path (Split-Path $backup) -Force | Out-Null
            Copy-Item -LiteralPath $destination -Destination $backup
            $published.Add([PSCustomObject]@{ Destination = $destination; Backup = $backup })
            Remove-Item -LiteralPath $destination -Force
        }
    } catch {
        $rollbackFailed = $false
        foreach ($file in $published) {
            try {
                if ($file.Backup) { Copy-Item -LiteralPath $file.Backup -Destination $file.Destination -Force }
                elseif (Test-Path -LiteralPath $file.Destination) { Remove-Item -LiteralPath $file.Destination -Force }
            } catch { $rollbackFailed = $true; Write-Warning "Output rollback failed for $($file.Destination): $_" }
        }
        if ($rollbackFailed) {
            $script:retainWork = $true
            throw "Output rollback incomplete. Recovery files retained in $work"
        }
        throw
    }
}
