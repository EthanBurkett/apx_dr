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
      [string]$Python = 'python', [switch]$Force, [switch]$PrepareOnly)
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
if ($Force -and !$PrepareOnly) {
    $art = [IO.Path]::GetFullPath((Join-Path $root 'art\ui\models'))
    if (!$art.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid render output directory.' }
    Get-ChildItem -LiteralPath $art -Filter 'apx_preview_*.png' -File | Remove-Item -Force
}
Push-Location $root
try {
    & $Python tools/prepare_model_assets.py
    if ($LASTEXITCODE -ne 0) { throw 'Model asset preparation failed.' }
    if ($PrepareOnly) { Write-Host 'Prepared importer and read-only model assets.'; return }
    & $Blender --background --factory-startup --python-exit-code 1 --python tools/render_models.py
    if ($LASTEXITCODE -ne 0) { throw 'Model rendering failed.' }
    $turnArgs = @()
    if ($Force) { $turnArgs = @('--', '--force') }
    & $Blender --background --factory-startup --python-exit-code 1 --python tools/render_turntables.py @turnArgs
    if ($LASTEXITCODE -ne 0) { throw 'Turntable rendering failed.' }
    # Native HLSL cannot be evaluated by Blender. Replace shader-equipped weapon
    # previews with actual D3D9 renders before the shared atlas packaging steps.
    if (Test-Path -LiteralPath (Join-Path $root 'ui\weapon_shaders.json')) {
        & $Blender --background --factory-startup --python-exit-code 1 --python tools/export_weapon_shader_mesh.py -- --all
        if ($LASTEXITCODE -ne 0) { throw 'Weapon shader mesh export failed.' }
        $shaderRegistry = Get-Content -LiteralPath (Join-Path $root 'ui\weapon_shaders.json') -Raw | ConvertFrom-Json
        foreach ($entry in $shaderRegistry.weapons.PSObject.Properties) {
            if ($null -eq $entry.Value.catalog_id) { continue } # Gameplay-only equipment has no browser tile.
            $category = 'weapon'; $effect = 'rift'
            if ($entry.Name -eq 'knife_mp') { $category = 'knife'; $effect = 'phasewire' }
            elseif ($entry.Name -ne 'beretta_mp') { $effect = $entry.Value.pixel_shader.Replace('apx_base_', '') }
            $id = $entry.Value.catalog_id
            & $Python tools/preview_weapon_shader.py --effect $effect --output "art/ui/models/apx_preview_${category}_$id.png" --frames-directory "build/shader-lab/still-$effect"
            if ($LASTEXITCODE -ne 0) { throw "Weapon shader still preview failed: $effect" }
            & $Python tools/preview_weapon_shader.py --effect $effect --turntable --width 512 --frames-directory "build/model-render/frames/apx_turn_${category}_$id"
            if ($LASTEXITCODE -ne 0) { throw "Weapon shader turntable preview failed: $effect" }
        }
    }
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
