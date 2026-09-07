param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Release',
    [ValidateSet('win-x64', 'win-arm64')][string]$Runtime = 'win-x64',
    [string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot '../Hue.Windows/Hue.Windows.csproj'
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $PSScriptRoot "../build/$Runtime" }
$platform = if ($Runtime -eq 'win-arm64') { 'ARM64' } else { 'x64' }
dotnet publish $project --configuration $Configuration --runtime $Runtime --self-contained true `
    -p:Platform=$platform -p:WindowsAppSDKSelfContained=true --output $OutputDirectory
if ($LASTEXITCODE -ne 0) { throw "Windows build failed with exit code $LASTEXITCODE." }
Write-Host "Built Hue: $OutputDirectory"
