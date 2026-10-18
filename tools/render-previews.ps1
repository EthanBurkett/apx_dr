#requires -Version 5.1
<#
.SYNOPSIS
Render real installed CoD4 meshes in an isolated Blender scene, then package previews.
.DESCRIPTION
Optional art-authoring task. Normal builds consume the checked-in PNG/IWI assets
and never need Blender. Existing renders are reused; -Force refreshes the catalog.
The pinned GPL importer is downloaded only into build, with SHA256 verification.
#>
[CmdletBinding()]
param([string]$Blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe',
      [string]$Python = 'python', [switch]$Force)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$work = Join-Path $root 'build\model-render'
$vendor = Join-Path $work 'vendor'
$zip = Join-Path $work 'importer.zip'
if (!(Test-Path -LiteralPath $Blender -PathType Leaf)) { throw "Blender missing: $Blender" }
New-Item -ItemType Directory -Path $vendor -Force | Out-Null
if (!(Test-Path -LiteralPath $zip)) {
    Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/mauserzjeh/cod-asset-importer/releases/download/v3.5/cod_asset_importer_v3.5.0.zip' -OutFile $zip
}
$expected = 'CC9E658377E7494EE195B6C99F053F960F2299474A6B46BE255B958AF0B21EAD'
if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $expected) { throw 'Model importer checksum mismatch.' }
Expand-Archive -LiteralPath $zip -DestinationPath $vendor -Force
if ($Force) {
    $art = [IO.Path]::GetFullPath((Join-Path $root 'art\ui\models'))
    if (!$art.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid render output directory.' }
    Get-ChildItem -LiteralPath $art -Filter 'apx_preview_*.png' -File | Remove-Item -Force
}
Push-Location $root
try {
    & $Python tools/prepare_model_assets.py
    if ($LASTEXITCODE -ne 0) { throw 'Model asset preparation failed.' }
    & $Blender --background --factory-startup --python-exit-code 1 --python tools/render_models.py
    if ($LASTEXITCODE -ne 0) { throw 'Model rendering failed.' }
    $turnArgs = @()
    if ($Force) { $turnArgs = @('--', '--force') }
    & $Blender --background --factory-startup --python-exit-code 1 --python tools/render_turntables.py @turnArgs
    if ($LASTEXITCODE -ne 0) { throw 'Turntable rendering failed.' }
    & $Python tools/package_turntables.py
    if ($LASTEXITCODE -ne 0) { throw 'Turntable packaging failed.' }
    & $Python tools/package_model_previews.py
    if ($LASTEXITCODE -ne 0) { throw 'Model material packaging failed.' }
    & $Python tools/package_preview_atlases.py
    if ($LASTEXITCODE -ne 0) { throw 'Still atlas packaging failed.' }
    & $Python tools/apply_content_profile.py
    if ($LASTEXITCODE -ne 0) { throw 'Active preview profile update failed.' }
    & $Python tools/generate_menus.py
    if ($LASTEXITCODE -ne 0) { throw 'Menu generation failed.' }
} finally { Pop-Location }
