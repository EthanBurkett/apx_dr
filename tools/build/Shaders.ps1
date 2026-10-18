# Compile project SM2/SM3 HLSL when source/compiler/SDK registry/output changes.
# All generated files live in assets; normal linker staging restores the SDK.
function Invoke-ProjectShaders {
    $shaderSource = Join-Path $modRoot 'src\shaders'
    if (!(Test-Path -LiteralPath $shaderSource)) { return }
    $files = @(Get-ChildItem -LiteralPath $shaderSource -Filter '*.hlsl' -File | Sort-Object Name)
    if (!$files.Count) { return }
    $compiler = Join-Path $scriptDirectory 'build\Shaders.cs'
    $sdkRegistry = Join-Path $GameRoot 'raw\shader_bin\shader_names'
    if (!(Test-Path -LiteralPath $sdkRegistry)) { throw 'SDK shader_names registry is missing.' }
    $nativeCompiler = Join-Path $env:SystemRoot 'System32\d3dcompiler_47.dll'
    $compilerSignature = Get-TextDigest ((Get-FileDigest $compiler) + (Get-FileDigest $nativeCompiler))
    $identity = @($compilerSignature, (Get-FileDigest (Join-Path $scriptDirectory 'build\Shaders.ps1')), (Get-FileDigest $sdkRegistry)) + @($files | ForEach-Object { $_.Name + ':' + (Get-FileDigest $_.FullName) })
    $signature = Get-TextDigest ($identity -join '|')
    $statePath = Join-Path $modRoot 'build\state\shaders.json'
    $state = $null
    if (Test-Path -LiteralPath $statePath) {
        try { $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json } catch { $state = $null }
    }
    $current = !$Force -and $state -and $state.signature -eq $signature
    if ($current) {
        foreach ($file in $state.files) {
            if (!(Test-Path -LiteralPath $file.path) -or (Get-FileDigest $file.path) -ne $file.hash) { $current = $false; break }
        }
    }
    if ($current) { Write-Step 'SHADERS' 'HLSL and generated binaries unchanged'; return }
    if (!('ApXShaderCompiler' -as [type])) { Add-Type -Path $compiler }
    $generated = @()
    $records = @()
    $compiled = 0
    $names = @{}
    $registry = [IO.File]::ReadAllBytes($sdkRegistry)
    foreach ($file in $files) {
        if ($file.Name -notmatch '^(vs|ps)_([23]_0)_([a-z0-9_]+)\.hlsl$') { throw "Invalid shader source filename: $($file.Name)" }
        $stage = $Matches[1]; $profile = $Matches[2]; $name = $Matches[3]
        $binary = [ApXShaderCompiler]::BinaryHash([ApXShaderCompiler]::NameHash($name))
        $destination = Join-Path $modRoot ('assets\shader_bin\' + $stage + '_' + $profile + '_' + $binary.ToString('x8'))
        $sourceSignature = Get-TextDigest ($compilerSignature + (Get-FileDigest $file.FullName))
        $previous = $null
        if ($state) { $previous = @($state.files | Where-Object { $_.path -eq $destination }) | Select-Object -First 1 }
        $reuse = !$Force -and $previous -and $previous.PSObject.Properties['sourceSignature'] -and
            $previous.sourceSignature -eq $sourceSignature -and (Test-Path -LiteralPath $destination) -and
            (Get-FileDigest $destination) -eq $previous.hash
        if ($reuse) { $records += $previous }
        else {
            $generated += [PSCustomObject]@{ path = $destination; sourceSignature = $sourceSignature; bytes = [ApXShaderCompiler]::Compile($file.FullName, $stage, $profile) }
            $compiled++
        }
        $names[$name] = $true
    }
    foreach ($name in @($names.Keys | Sort-Object)) { $registry = [ApXShaderCompiler]::Registry($registry, $name) }
    $generated += [PSCustomObject]@{ path = (Join-Path $modRoot 'assets\shader_bin\shader_names'); sourceSignature = ''; bytes = $registry }
    foreach ($item in $generated) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $item.path) -Force | Out-Null
        $same = $false
        if (Test-Path -LiteralPath $item.path) {
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $digest = [BitConverter]::ToString($sha.ComputeHash($item.bytes)).Replace('-','') }
            finally { $sha.Dispose() }
            $same = (Get-FileDigest $item.path) -eq $digest
        }
        if (!$same) { [IO.File]::WriteAllBytes($item.path, $item.bytes) }
        $records += [PSCustomObject]@{ path = $item.path; sourceSignature = $item.sourceSignature; hash = (Get-FileDigest $item.path -Refresh) }
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $statePath) -Force | Out-Null
    [IO.File]::WriteAllText($statePath, (@{ signature = $signature; files = $records } | ConvertTo-Json -Depth 5))
    Write-Step 'SHADERS' ("Compiled {0} changed HLSL stages and merged SDK registry" -f $compiled)
}
