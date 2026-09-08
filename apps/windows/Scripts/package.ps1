param(
    [Parameter(Mandatory)][string]$X64AppDirectory,
    [Parameter(Mandatory)][string]$Arm64AppDirectory,
    [string]$OutputDirectory,
    [string]$OutputBaseName
)
$ErrorActionPreference = 'Stop'

if (-not $OutputDirectory) { $OutputDirectory = Join-Path $PSScriptRoot '../installers' }
$x64AppPath = (Resolve-Path -LiteralPath $X64AppDirectory).Path
$arm64AppPath = (Resolve-Path -LiteralPath $Arm64AppDirectory).Path
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)

function Test-PublishedApp([string]$AppPath, [string]$Runtime, [UInt16]$ExpectedMachine) {
    if ($outputPath.Equals($AppPath, [StringComparison]::OrdinalIgnoreCase) -or
        $outputPath.StartsWith($AppPath.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The installer output directory must be outside both published app directories.'
    }
    foreach ($file in 'Hue.exe', 'Hue.deps.json', 'Hue.runtimeconfig.json', 'coreclr.dll') {
        if (-not (Test-Path -LiteralPath (Join-Path $AppPath $file) -PathType Leaf)) {
            throw "Missing $file. Run build.ps1 for $Runtime before packaging."
        }
    }
    foreach ($file in 'Hue.exe', 'coreclr.dll') {
        $reader = [IO.BinaryReader]::new([IO.File]::OpenRead((Join-Path $AppPath $file)))
        try {
            if ($reader.ReadUInt16() -ne 0x5A4D) { throw "$file is not a Windows executable." }
            $reader.BaseStream.Position = 0x3C
            $reader.BaseStream.Position = $reader.ReadInt32()
            if ($reader.ReadUInt32() -ne 0x00004550 -or $reader.ReadUInt16() -ne $ExpectedMachine) {
                throw "$file does not match the requested $Runtime architecture."
            }
        } finally {
            $reader.Dispose()
        }
    }
}

Test-PublishedApp $x64AppPath 'win-x64' 0x8664
Test-PublishedApp $arm64AppPath 'win-arm64' 0xAA64

$compiler = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe'
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if (-not $command) { throw 'Install Inno Setup 6.3 or later to package Hue.' }
    $compiler = $command.Source
}
[xml]$project = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../Hue.Windows/Hue.Windows.csproj') -Raw
$version = $project.SelectSingleNode('/Project/PropertyGroup/Version').InnerText
if ($version -notmatch '^\d+\.\d+\.\d+(\.\d+)?$') { throw 'The app version must be a numeric release version.' }
if (-not $OutputBaseName) { $OutputBaseName = "Hue-Camera-Viewer-$version-Windows" }
if ($OutputBaseName -notmatch '^[A-Za-z0-9._-]+$') { throw 'The installer name may only contain letters, digits, dots, dashes and underscores.' }
$iconPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../../assets/Hue.ico')).Path
$arguments = @(
    "/DX64AppDirectory=$x64AppPath"
    "/DArm64AppDirectory=$arm64AppPath"
    "/DOutputDirectory=$outputPath"
    "/DAppVersion=$version"
    "/DOutputBaseName=$OutputBaseName"
    "/DSetupIconPath=$iconPath"
    (Join-Path $PSScriptRoot 'installer.iss')
)
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { throw "Installer packaging failed with exit code $LASTEXITCODE." }
$installer = Join-Path $outputPath "$OutputBaseName.exe"
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) { throw 'The installer was not created.' }
Write-Host "Packaged Hue: $installer"
