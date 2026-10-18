#requires -Version 5.1
<#
.SYNOPSIS
Build an isolated test package and verify configured prestiges on a real CoD4x bot.
.DESCRIPTION
Never modifies release source, dist or human player profiles. Keeps fixture/logs
under build for inspection. Requires the installed SDK and Windows CoD4x binary.
#>
[CmdletBinding()]
param([string]$GameRoot, [string]$Executable = 'apx_cod4x_dedrun.exe',
    [ValidateSet('Progression','Efr','Hud','Menus','Content','Traffic','Equipment')][string]$Suite = 'Progression')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..'))
if (!$GameRoot) { $GameRoot = [IO.Path]::GetFullPath((Join-Path $root '..\..')) }
$fixture = Join-Path $root ('build\pt-' + [Guid]::NewGuid().ToString('N').Substring(0,12))
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
try {
    New-Item -ItemType Directory -Path $fixture -Force | Out-Null
    foreach ($directory in @('src', 'assets', 'manifests', 'ui')) {
        Copy-Item -LiteralPath (Join-Path $root $directory) -Destination (Join-Path $fixture $directory) -Recurse
    }
    # Never copy private operator inputs into fixtures, even temporarily.
    $configRoot = Join-Path $root 'config'
    foreach ($file in Get-ChildItem -LiteralPath $configRoot -Recurse -File) {
        if ($file.Name -ieq 'private.cfg') { continue }
        $relative = $file.FullName.Substring($configRoot.Length + 1)
        $target = Join-Path $fixture ('config\' + $relative)
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target
    }
    New-Item -ItemType Directory -Path (Join-Path $fixture 'tools') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'tools\build.ps1') -Destination (Join-Path $fixture 'tools\build.ps1')
    Copy-Item -LiteralPath (Join-Path $root 'tools\build') -Destination (Join-Path $fixture 'tools\build') -Recurse
    Copy-Item -LiteralPath (Join-Path $root 'project.json') -Destination (Join-Path $fixture 'project.json')
    if ($Suite -eq 'Menus') {
        # Stress the browser with 100 additional choices only inside this fixture.
        $catalog = Join-Path $fixture 'src\mp\apx_catalog.csv'
        $baseCount = @(Get-Content -LiteralPath (Join-Path $fixture 'src\mp\itemTable.csv') | Where-Object { $_.Trim() }).Count
        $rows = @(0..99 | ForEach-Object { 'weapon:' + ($_ + $baseCount) + ',weapon,' + ($_ + $baseCount) + ',Fixture item ' + $_.ToString('00') + ',Browser stress fixture,apx_preview_weapon_0,999,apx_turn_weapon_0' })
        Add-Content -LiteralPath $catalog -Value $rows
    }
    $driver = Join-Path $fixture 'src\braxi\_progression_runtime_test.gsc'
    $testSource = 'tests\runtime\progression.gsc'
    $marker = 'APX_PROGRESSION_RUNTIME_PASS'
    $duration = 20
    if ($Suite -eq 'Efr') { $testSource = 'tests\runtime\efr.gsc'; $marker = 'APX_EFR_RUNTIME_PASS'; $duration = 30 }
    if ($Suite -eq 'Hud') { $testSource = 'tests\runtime\hud.gsc'; $marker = 'APX_HUD_RUNTIME_PASS'; $duration = 15 }
    if ($Suite -eq 'Menus') { $testSource = 'tests\runtime\menus.gsc'; $marker = 'APX_MENUS_RUNTIME_PASS'; $duration = 60 }
    if ($Suite -eq 'Content') { $testSource = 'tests\runtime\content.gsc'; $marker = 'APX_CONTENT_RUNTIME_PASS'; $duration = 60 }
    if ($Suite -eq 'Traffic') { $testSource = 'tests\runtime\menu_traffic.gsc'; $marker = 'APX_MENU_TRAFFIC_RUNTIME_PASS'; $duration = 20 }
    if ($Suite -eq 'Equipment') { $testSource = 'tests\runtime\equipment.gsc'; $marker = 'APX_EQUIPMENT_RUNTIME_PASS'; $duration = 60 }
    Copy-Item -LiteralPath (Join-Path $root $testSource) -Destination $driver
    $gametype = [IO.File]::ReadAllText((Join-Path $root 'src\maps\mp\gametypes\deathrun.gsc'))
    $gametype = $gametype.Replace('braxi\_mod::main();', 'braxi\_mod::main(); thread braxi\_progression_runtime_test::run();')
    [IO.File]::WriteAllText((Join-Path $fixture 'src\maps\mp\gametypes\apx_progression_test.gsc'), $gametype)
    Add-Content -LiteralPath (Join-Path $fixture 'manifests\00-scripts.csv') -Value "rawfile,braxi/_progression_runtime_test.gsc`nrawfile,maps/mp/gametypes/apx_progression_test.gsc"
    & $powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture 'tools\build.ps1') -GameRoot $GameRoot
    if ($LASTEXITCODE -ne 0) { throw "Test fixture build failed: $fixture" }
    & $powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\test-runtime.ps1') -GameRoot $GameRoot -Executable $Executable -ModDirectory (Join-Path $fixture 'dist') -GameType apx_progression_test -Map mp_backlot -Duration $duration -RequiredMarker $marker
    exit $LASTEXITCODE
} catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
