#requires -Version 5.1
# Isolated native-compiler/cache checks. Never writes to the real SDK or dist.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..'))
$fixture = Join-Path $root ('build\shader-tests\' + [Guid]::NewGuid().ToString('N'))
$modRoot = Join-Path $fixture 'mod'
$GameRoot = Join-Path $fixture 'sdk'
$scriptDirectory = Join-Path $modRoot 'tools'
$Force = $false
$script:fileDigests = @{}
$script:steps = @()
$passed = 0
function Write-Step($Name,$Message) { $script:steps += $Message }
function Assert-True($Value,$Message) { if (!$Value) { throw $Message }; $script:passed++ }
function Invoke-TestCompile { $script:fileDigests = @{}; $script:steps = @(); Invoke-ProjectShaders }
try {
    foreach ($path in @('src\shaders','assets\shader_bin','tools\build')) { New-Item -ItemType Directory -Path (Join-Path $modRoot $path) -Force | Out-Null }
    New-Item -ItemType Directory -Path (Join-Path $GameRoot 'raw\shader_bin') -Force | Out-Null
    # Keep the two-stage cache fixture stable as the release adds more effects.
    Copy-Item -Path (Join-Path $root 'src\shaders\*apx_xp_fill.hlsl') -Destination (Join-Path $modRoot 'src\shaders')
    Copy-Item -Path (Join-Path $root 'tools\build\Shaders.*') -Destination (Join-Path $scriptDirectory 'build')
    $sdkRegistry = Join-Path $GameRoot 'raw\shader_bin\shader_names'
    $installedRegistry = Join-Path $root '..\..\raw\shader_bin\shader_names'
    if (Test-Path -LiteralPath $installedRegistry) {
        Copy-Item -LiteralPath $installedRegistry -Destination $sdkRegistry
    } else {
        # SDK-free CI still exercises the real compiler and registry/cache format.
        [IO.File]::WriteAllBytes($sdkRegistry, [byte[]]::new(8))
    }
    . (Join-Path $root 'tools\build\Cache.ps1')
    . (Join-Path $root 'tools\build\Shaders.ps1')
    $sdkBefore = Get-FileDigest $sdkRegistry
    Invoke-TestCompile
    Assert-True (($script:steps -join ' ') -match 'Compiled 2 changed') 'Initial compile did not compile both stages'
    $vertex = @(Get-ChildItem (Join-Path $modRoot 'assets\shader_bin\vs_*'))[0].FullName
    $pixel = @(Get-ChildItem (Join-Path $modRoot 'assets\shader_bin\ps_*'))[0].FullName
    $vertexHash = Get-FileDigest $vertex
    $pixelHash = Get-FileDigest $pixel
    $vertexTime = [IO.File]::GetLastWriteTimeUtc($vertex)
    Invoke-TestCompile
    Assert-True (($script:steps -join ' ') -match 'unchanged') 'No-op shader build did not skip'
    Assert-True ([IO.File]::GetLastWriteTimeUtc($vertex) -eq $vertexTime) 'No-op shader build rewrote a binary'
    $pixelSource = Join-Path $modRoot 'src\shaders\ps_3_0_apx_xp_fill.hlsl'
    $original = [IO.File]::ReadAllText($pixelSource)
    [IO.File]::WriteAllText($pixelSource,$original.Replace('color.rgb *= face;','color.rgb *= face * 0.95;'))
    Invoke-TestCompile
    Assert-True (($script:steps -join ' ') -match 'Compiled 1 changed') 'Pixel-only edit recompiled the other stage'
    Assert-True ((Get-FileDigest $vertex) -eq $vertexHash -and [IO.File]::GetLastWriteTimeUtc($vertex) -eq $vertexTime) 'Pixel edit changed the vertex shader'
    Assert-True ((Get-FileDigest $pixel) -ne $pixelHash) 'Pixel edit did not change its compiled shader'
    $goodPixel = Get-FileDigest $pixel
    [IO.File]::WriteAllText($pixelSource, 'this is not HLSL')
    $failed = $false
    try { Invoke-TestCompile } catch { $failed = $true }
    Assert-True $failed 'Invalid HLSL unexpectedly succeeded'
    Assert-True ((Get-FileDigest $pixel -Refresh) -eq $goodPixel) 'Failed HLSL compilation changed the last good output'
    [IO.File]::WriteAllText($pixelSource,$original)
    [IO.File]::WriteAllText($pixel,'corrupt')
    Invoke-TestCompile
    Assert-True (($script:steps -join ' ') -match 'Compiled 1 changed') 'Corrupted shader output was not repaired individually'
    Assert-True ((Get-FileDigest $sdkRegistry -Refresh) -eq $sdkBefore) 'Shader compilation modified its SDK registry'
    $Force = $true
    Invoke-TestCompile
    Assert-True (($script:steps -join ' ') -match 'Compiled 2 changed') 'Force did not compile both stages'
    $Force = $false
    Copy-Item -Path (Join-Path $root 'src\shaders\*_2_0_apx_preview*.hlsl') -Destination (Join-Path $modRoot 'src\shaders')
    Invoke-TestCompile
    Assert-True (($script:steps -join ' ') -match 'Compiled 3 changed') 'Shared preview SM2 shader stages did not compile'
    foreach ($binary in Get-ChildItem (Join-Path $modRoot 'assets\shader_bin\*_2_0_*')) {
        Assert-True (([BitConverter]::ToUInt32([IO.File]::ReadAllBytes($binary.FullName),4) -band 0xffff) -eq 0x0200) 'SM2 output has the wrong shader bytecode version'
    }
    Copy-Item -Path (Join-Path $root 'src\shaders\*_3_0_apx_rift_*.hlsl') -Destination (Join-Path $modRoot 'src\shaders')
    Invoke-TestCompile
    Assert-True (($script:steps -join ' ') -match 'Compiled 3 changed') 'The weapon vertex/body/corona stages did not compile'
    foreach ($stage in @('vs_3_0_bd8f9512', 'ps_3_0_e1edf03f', 'ps_3_0_4fe22cbf')) {
        $binary = Join-Path $modRoot ('assets\shader_bin\' + $stage)
        Assert-True (([BitConverter]::ToUInt32([IO.File]::ReadAllBytes($binary),4) -band 0xffff) -eq 0x0300) 'Weapon shader has the wrong bytecode version'
    }
    Copy-Item -Path (Join-Path $root 'src\shaders\*apx_phasewire.hlsl') -Destination (Join-Path $modRoot 'src\shaders')
    Invoke-TestCompile
    Assert-True (($script:steps -join ' ') -match 'Compiled 4 changed') 'SM2/SM3 knife vertex/pixel stages did not compile'
    $wireStages = @(Get-ChildItem (Join-Path $modRoot 'assets\shader_bin') | Where-Object { $_.Name -match '^[vp]s_[23]_0_' })
    Assert-True ($wireStages.Count -eq 12) 'Expected all twelve XP, preview, M9 and knife compiled stages'
    Write-Host ("PASS: {0} native HLSL/cache assertions." -f $passed) -ForegroundColor Green
} catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }

exit 0
