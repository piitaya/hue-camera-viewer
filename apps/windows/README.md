# Hue for Windows

A minimal camera viewer for Windows 10 (2004)+ and Windows 11, in English and French.

Extract the preview ZIP, open `Hue.exe`, and choose your camera.
Captures are saved as PNG files on your Desktop.

## Development

Run these commands from `apps/windows` on Windows with the .NET 8 SDK
and the Windows App SDK build tools installed.

```powershell
./Scripts/build.ps1
./build/win-x64/Hue.exe --demo
```

Use `-Runtime win-arm64` to build for ARM64.
The output folder includes the app's runtime dependencies.

Run the core tests on any platform with:

```sh
dotnet test Hue.Core.Tests
```

GitHub Actions builds both Windows architectures. Download the preview ZIP
from the workflow's artifacts to try it on a PC.
