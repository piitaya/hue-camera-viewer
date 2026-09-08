#ifndef X64AppDirectory
  #error Run package.ps1 to compile the installer.
#endif
#ifndef Arm64AppDirectory
  #error Run package.ps1 to compile the installer.
#endif

[Setup]
AppId={{ADB72C20-A36B-497A-9876-47A9D381EC49}
AppName=Hue Camera Viewer
AppVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\Hue
PrivilegesRequired=lowest
DisableDirPage=yes
DisableProgramGroupPage=yes
UninstallDisplayName=Hue
UninstallDisplayIcon={app}\Hue.exe
OutputDir={#OutputDirectory}
OutputBaseFilename={#OutputBaseName}
SetupIconFile={#SetupIconPath}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
LanguageDetectionMethod=uilanguage
ShowLanguageDialog=no
CloseApplications=yes
RestartApplications=no
ArchitecturesAllowed=x64os or arm64
ArchitecturesInstallIn64BitMode=x64os or arm64
MinVersion=10.0.19041

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[CustomMessages]
english.Arm64WindowsVersionRequired=Hue requires Windows 11 or later on ARM64 computers.
french.Arm64WindowsVersionRequired=Hue nécessite Windows 11 ou une version ultérieure sur les ordinateurs ARM64.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#X64AppDirectory}\*"; DestDir: "{app}"; Check: not IsArm64; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#Arm64AppDirectory}\*"; DestDir: "{app}"; Check: IsArm64; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{userprograms}\Hue"; Filename: "{app}\Hue.exe"; WorkingDir: "{app}"
Name: "{userdesktop}\Hue"; Filename: "{app}\Hue.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\Hue.exe"; Description: "{cm:LaunchProgram,Hue}"; Flags: nowait postinstall skipifsilent

[Code]
function InitializeSetup: Boolean;
var
  Version: TWindowsVersion;
begin
  Result := True;
  if IsArm64 then
  begin
    GetWindowsVersionEx(Version);
    if (Version.Major = 10) and (Version.Build < 22000) then
    begin
      SuppressibleMsgBox(CustomMessage('Arm64WindowsVersionRequired'), mbCriticalError, MB_OK, IDOK);
      Result := False;
    end;
  end;
end;
