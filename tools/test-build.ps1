#requires -Version 5.1
<#
.SYNOPSIS
Exercise build success, failure, SDK restoration and reproducible ZIP output in an isolated fixture.
.DESCRIPTION
Uses a small test linker compiled with the Windows .NET Framework C# compiler.
Does not run the game or modify the real CoD4 SDK.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..'))
$testParent = Join-Path $sourceRoot 'build\tests'
$fixture = Join-Path $testParent ([Guid]::NewGuid().ToString('N'))
$game = Join-Path $fixture 'Game With Spaces'
$mod = Join-Path $game 'Mods\apx_dr'
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$passed = 0

function Assert-True([bool]$Value, [string]$Message) {
    if (!$Value) { throw $Message }
    $script:passed++
}
function Put-File([string]$Path, [string]$Text) {
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    [IO.File]::WriteAllText($Path, $Text)
}
function Invoke-Build([string]$Target = 'All', [string[]]$Extra = @()) {
    $output = & $powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $mod 'tools\build.ps1') -Target $Target @Extra 2>&1
    return [PSCustomObject]@{ Code = $LASTEXITCODE; Text = ($output -join "`n") }
}
try {
    New-Item -ItemType Directory -Path (Join-Path $game 'bin'), (Join-Path $game 'zone_source'), (Join-Path $mod 'tools') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'tools\build.ps1') -Destination (Join-Path $mod 'tools\build.ps1')
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'tools\build') -Destination (Join-Path $mod 'tools\build') -Recurse
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'project.json') -Destination (Join-Path $mod 'project.json')
    # This fixture runs its own tiny managed linker, not the fingerprinted SDK.
    $fixtureProject = Get-Content -LiteralPath (Join-Path $mod 'project.json') -Raw | ConvertFrom-Json
    $fixtureProject.PSObject.Properties.Remove('linkerMemoryProfile')
    [IO.File]::WriteAllText((Join-Path $mod 'project.json'), ($fixtureProject | ConvertTo-Json -Depth 10))
    Put-File (Join-Path $game 'raw\braxi\test.gsc') 'SDK original'
    Put-File (Join-Path $mod 'src\braxi\test.gsc') 'main() {}'
    Put-File (Join-Path $mod 'ui\inactive_images.json') '["inactive.iwi"]'
    Put-File (Join-Path $mod 'assets\images\inactive.iwi') 'inactive source must not ship'
    Put-File (Join-Path $mod 'src\braxi\new.gsc') 'main() {}'
    Put-File (Join-Path $mod 'manifests\00-scripts.csv') "rawfile,braxi/test.gsc`nrawfile,braxi/new.gsc`n"
    foreach ($name in @('src\DeathRun_ReadMe.txt', 'src\content_credits.txt', 'src\cleanup.cfg', 'config\dr_sprays.cfg', 'config\dr_songs.cfg',
        'config\deathrun.cfg', 'config\server.cfg', 'config\server\rules.cfg', 'config\deathrun\rounds.cfg',
        'config\private.example.cfg', 'assets\images\test.iwi', 'assets\sound\test.wav', 'src\weapons\mp\test')) {
        Put-File (Join-Path $mod $name) 'fixture'
    }
    $stub = @'
using System;
using System.IO;
class TestLinker {
    static int Main(string[] args) {
        string root = Path.GetFullPath("..");
        string zone = args[args.Length - 1];
        string language = args[1];
        if (File.ReadAllText(Path.Combine(root, "raw", "braxi", "test.gsc")) != "main() {}") return 5;
        if (!File.Exists(Path.Combine(root, "raw", "braxi", "new.gsc"))) return 6;
        string output = Path.Combine(root, "zone", language);
        Directory.CreateDirectory(output);
        File.WriteAllText(Path.Combine(output, zone + ".ff"), "fixture fastfile");
        if (File.Exists(Path.Combine(root, "fail-menu"))) Console.WriteLine("Menu load error: fixture.menu, line 1: expected integer but found style");
        else if (File.Exists(Path.Combine(root, "fail-linker"))) Console.WriteLine("ERROR: deliberately failed, exit zero");
        else Console.WriteLine("process...link...compress...save...done.");
        return 0;
    }
}
'@
    Add-Type -TypeDefinition $stub -Language CSharp -OutputType ConsoleApplication -OutputAssembly (Join-Path $game 'bin\linker_pc.exe')
    Put-File (Join-Path $mod 'dist\mod.ff') 'previous working fastfile'
    Put-File (Join-Path $mod 'dist\apx_dr.iwd') 'previous working archive'
    Put-File (Join-Path $mod 'config\private.cfg') 'private fixture secret'
    Put-File (Join-Path $game 'zone_source\mod.csv') 'original SDK zone manifest'
    Put-File (Join-Path $game 'zone\english\mod.ff') 'original SDK zone fastfile'
    Put-File (Join-Path $game 'fail-linker') 'fail'
    $failed = Invoke-Build
    Assert-True ($failed.Code -ne 0) 'A linker error with exit zero must fail the build.'
    Assert-True (([IO.File]::ReadAllText((Join-Path $mod 'dist\mod.ff'))) -eq 'previous working fastfile') 'A failed build replaced mod.ff.'
    Assert-True (([IO.File]::ReadAllText((Join-Path $mod 'dist\apx_dr.iwd'))) -eq 'previous working archive') 'A failed build replaced an IWD.'
    Assert-True (([IO.File]::ReadAllText((Join-Path $game 'raw\braxi\test.gsc'))) -eq 'SDK original') 'SDK content was not restored after failure.'
    Assert-True (!(Test-Path -LiteralPath (Join-Path $game 'raw\braxi\new.gsc'))) 'New SDK overlay files remained after failure.'
    Assert-True (([IO.File]::ReadAllText((Join-Path $game 'zone_source\mod.csv'))) -eq 'original SDK zone manifest') 'SDK zone manifest was not restored after failure.'
    Assert-True (([IO.File]::ReadAllText((Join-Path $game 'zone\english\mod.ff'))) -eq 'original SDK zone fastfile') 'SDK zone fastfile was not restored after failure.'
    Remove-Item -LiteralPath (Join-Path $game 'fail-linker')
    Put-File (Join-Path $game 'fail-menu') 'fail'
    $badMenu = Invoke-Build
    Assert-True ($badMenu.Code -ne 0) 'An exit-zero menu compiler error must fail the build.'
    Assert-True (([IO.File]::ReadAllText((Join-Path $mod 'dist\mod.ff'))) -eq 'previous working fastfile') 'A menu compiler error replaced the working fastfile.'
    Remove-Item -LiteralPath (Join-Path $game 'fail-menu')
    $success = Invoke-Build
    Assert-True ($success.Code -eq 0) ("Fixture build failed: " + $success.Text)
    Assert-True (([IO.File]::ReadAllText((Join-Path $mod 'dist\mod.ff'))) -eq 'fixture fastfile') 'Successful fastfile was not published.'
    Assert-True (([IO.File]::ReadAllText((Join-Path $game 'raw\braxi\test.gsc'))) -eq 'SDK original') 'SDK content was not restored after success.'
    Assert-True (!(Test-Path -LiteralPath (Join-Path $game 'raw\braxi\new.gsc'))) 'New SDK overlay files remained after success.'
    Assert-True (([IO.File]::ReadAllText((Join-Path $game 'zone_source\mod.csv'))) -eq 'original SDK zone manifest') 'SDK zone manifest was not restored after success.'
    Assert-True (([IO.File]::ReadAllText((Join-Path $game 'zone\english\mod.ff'))) -eq 'original SDK zone fastfile') 'SDK zone fastfile was not restored after success.'
    Assert-True (([IO.File]::ReadAllText((Join-Path $mod 'dist\config\private.cfg'))) -eq 'private fixture secret') 'Private configuration was not copied loose.'
    $fastfileTime = (Get-Item -LiteralPath (Join-Path $mod 'dist\mod.ff')).LastWriteTimeUtc
    $archiveTime = (Get-Item -LiteralPath (Join-Path $mod 'dist\apx_dr.iwd')).LastWriteTimeUtc
    $soundTime = (Get-Item -LiteralPath (Join-Path $mod 'dist\apx_dr_sounds.iwd')).LastWriteTimeUtc
    $configTime = (Get-Item -LiteralPath (Join-Path $mod 'dist\server.cfg')).LastWriteTimeUtc
    $noop = Invoke-Build
    Assert-True ($noop.Code -eq 0 -and ([regex]::Matches($noop.Text, '\[SKIP\s*\]')).Count -eq 3) 'An unchanged build must skip all three artifacts.'
    Assert-True ((Get-Item -LiteralPath (Join-Path $mod 'dist\mod.ff')).LastWriteTimeUtc -eq $fastfileTime) 'An unchanged fastfile was rewritten.'
    Assert-True ((Get-Item -LiteralPath (Join-Path $mod 'dist\server.cfg')).LastWriteTimeUtc -eq $configTime) 'An unchanged config was rewritten.'
    Put-File (Join-Path $mod 'src\braxi\test.gsc') 'main() { /* changed script */ }'
    $scriptEdit = Invoke-Build
    Assert-True ($scriptEdit.Code -ne 0) 'A changed script must invoke the fixture linker (which deliberately rejects the changed contents).'
    Assert-True ((Get-Item -LiteralPath (Join-Path $mod 'dist\mod.ff')).LastWriteTimeUtc -eq $fastfileTime) 'A failed incremental link replaced the previous fastfile.'
    Put-File (Join-Path $mod 'src\braxi\test.gsc') 'main() {}'
    Put-File (Join-Path $mod 'config\server.cfg') 'changed config'
    $configEdit = Invoke-Build
    Assert-True ($configEdit.Code -eq 0 -and ([regex]::Matches($configEdit.Text, '\[SKIP\s*\]')).Count -eq 3) 'A config-only edit rebuilt binary artifacts.'
    Assert-True (([IO.File]::ReadAllText((Join-Path $mod 'dist\server.cfg'))) -eq 'changed config') 'The changed loose config was not published.'
    Put-File (Join-Path $mod 'assets\images\test.iwi') 'changed image'
    $imageEdit = Invoke-Build
    Assert-True ($imageEdit.Code -eq 0 -and !$imageEdit.Text.Contains('apx_dr.iwd: unchanged') -and $imageEdit.Text.Contains('apx_dr_sounds.iwd: unchanged')) 'An image edit must rebuild its IWD and leave the sound IWD alone.'
    Assert-True ((Get-Item -LiteralPath (Join-Path $mod 'dist\apx_dr_sounds.iwd')).LastWriteTimeUtc -eq $soundTime) 'An unrelated sound archive was rewritten.'
    [IO.File]::WriteAllText((Join-Path $mod 'dist\mod.ff'), 'corrupted output')
    $corrupted = Invoke-Build
    Assert-True ($corrupted.Code -eq 0 -and !$corrupted.Text.Contains('mod.ff: unchanged')) 'A changed output must invalidate the cache.'
    Assert-True (([IO.File]::ReadAllText((Join-Path $mod 'dist\mod.ff'))) -eq 'fixture fastfile') 'A corrupted fastfile was not repaired.'
    Put-File (Join-Path $game 'raw\stock-dependency.txt') 'SDK changed'
    $sdkEdit = Invoke-Build
    Assert-True ($sdkEdit.Code -eq 0 -and $sdkEdit.Text.Contains('[LINK')) 'An SDK dependency change did not invalidate the fastfile.'
    $sdkRepeat = Invoke-Build
    Assert-True ($sdkRepeat.Code -eq 0 -and ([regex]::Matches($sdkRepeat.Text, '\[SKIP\s*\]')).Count -eq 3) 'Updated incremental state was not committed.'
    Assert-True (!$sdkRepeat.Text.Contains('incremental state could not be saved')) 'Incremental cache replacement failed.'
    $first = (Get-FileHash -LiteralPath (Join-Path $mod 'dist\apx_dr.iwd')).Hash
    $repeat = Invoke-Build 'Iwd' @('-Force')
    Assert-True ($repeat.Code -eq 0) $repeat.Text
    Assert-True ($first -eq (Get-FileHash -LiteralPath (Join-Path $mod 'dist\apx_dr.iwd')).Hash) 'Repeated IWD builds differ.'
    Assert-True (!$repeat.Text.Contains('apx_dr.iwd: unchanged')) '-Force did not bypass incremental state.'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead((Join-Path $mod 'dist\apx_dr.iwd'))
    try {
        Assert-True ($null -ne $archive.GetEntry('images/test.iwi')) 'ZIP asset path is wrong.'
        Assert-True ($null -eq $archive.GetEntry('images/inactive.iwi')) 'Inactive source images were packaged.'
        Assert-True ($null -ne $archive.GetEntry('dr_sprays.cfg')) 'Spray configuration was not packaged.'
        Assert-True (@($archive.Entries | Where-Object { $_.FullName -match 'private' }).Count -eq 0) 'Private configuration leaked into the IWD.'
    } finally { $archive.Dispose() }
    $overlap = Invoke-Build 'Iwd' @('-OutputDirectory', (Join-Path $mod 'assets\images'))
    Assert-True ($overlap.Code -ne 0) 'An output directory overlapping source was accepted.'
    $planPath = Join-Path $mod 'project.json'
    $originalPlan = [IO.File]::ReadAllText($planPath)
    $plan = $originalPlan | ConvertFrom-Json
    $plan.archives[0].entries += [PSCustomObject]@{ source = 'config/private.cfg'; path = 'config/private.cfg' }
    [IO.File]::WriteAllText($planPath, ($plan | ConvertTo-Json -Depth 10))
    Assert-True ((Invoke-Build 'Check').Code -ne 0) 'Private configuration was allowed in an IWD plan.'
    $plan.archives[0].entries[-1].path = '../escape.cfg'
    [IO.File]::WriteAllText($planPath, ($plan | ConvertTo-Json -Depth 10))
    Assert-True ((Invoke-Build 'Check').Code -ne 0) 'Archive path traversal was accepted.'
    [IO.File]::WriteAllText($planPath, $originalPlan)
    Add-Content -LiteralPath (Join-Path $mod 'manifests\00-scripts.csv') -Value 'rawfile,missing.gsc'
    $missing = Invoke-Build 'Check'
    Assert-True ($missing.Code -ne 0) 'A missing manifest dependency was accepted.'
    Write-Host ("PASS: {0} build assertions (including failure preservation, SDK restore and reproducibility)." -f $passed) -ForegroundColor Green
} finally {
    $resolved = [IO.Path]::GetFullPath($fixture)
    $allowed = [IO.Path]::GetFullPath($testParent) + '\'
    if ($resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
