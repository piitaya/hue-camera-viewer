param(
    [ValidateSet('win-x64', 'win-arm64')][string]$Runtime = 'win-x64',
    [string]$AppDirectory,
    [string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'

if (-not $AppDirectory) { $AppDirectory = Join-Path $PSScriptRoot "../build/$Runtime" }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $PSScriptRoot '../installers' }
$appPath = (Resolve-Path -LiteralPath $AppDirectory).Path
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
if ($outputPath.Equals($appPath, [StringComparison]::OrdinalIgnoreCase) -or
    $outputPath.StartsWith($appPath.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The installer output directory must be outside the published app directory.'
}
foreach ($file in 'Hue.exe', 'Hue.deps.json', 'Hue.runtimeconfig.json', 'coreclr.dll') {
    if (-not (Test-Path -LiteralPath (Join-Path $appPath $file) -PathType Leaf)) {
        throw "Missing $file. Run build.ps1 for $Runtime before packaging."
    }
}

$architecture = if ($Runtime -eq 'win-arm64') { 'arm64' } else { 'x64' }
$expectedMachine = if ($Runtime -eq 'win-arm64') { 0xAA64 } else { 0x8664 }
$reader = [IO.BinaryReader]::new([IO.File]::OpenRead((Join-Path $appPath 'Hue.exe')))
try {
    $reader.BaseStream.Position = 0x3C
    $reader.BaseStream.Position = $reader.ReadInt32()
    if ($reader.ReadUInt32() -ne 0x00004550 -or $reader.ReadUInt16() -ne $expectedMachine) {
        throw "Hue.exe does not match the requested $Runtime architecture."
    }
} finally {
    $reader.Dispose()
}

$compiler = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe'
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if (-not $command) { throw 'Install Inno Setup 6.3 or later to package Hue.' }
    $compiler = $command.Source
}
[xml]$project = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../Hue.Windows/Hue.Windows.csproj') -Raw
$version = $project.SelectSingleNode('/Project/PropertyGroup/Version').InnerText
if ($version -notmatch '^\d+\.\d+\.\d+(\.\d+)?$') { throw 'The app version must be a numeric release version.' }
$iconPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../../assets/Hue.ico')).Path
$arguments = @(
    "/DAppDirectory=$appPath"
    "/DOutputDirectory=$outputPath"
    "/DAppArchitecture=$architecture"
    "/DAppVersion=$version"
    "/DSetupIconPath=$iconPath"
    (Join-Path $PSScriptRoot 'installer.iss')
)
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { throw "Installer packaging failed with exit code $LASTEXITCODE." }
$installer = Join-Path $outputPath "Hue-Setup-$architecture.exe"
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) { throw 'The installer was not created.' }
Write-Host "Packaged Hue: $installer"
