#ifndef X64AppDirectory
  #error Run package.ps1 to compile the installer.
#endif
#ifndef Arm64AppDirectory
  #error Run package.ps1 to compile the installer.
#endif

[Setup]
AppId={{E4019837-B47D-43AD-A263-1AD79EBBDD30}
AppName=Girafon
AppVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\Girafon
PrivilegesRequired=lowest
DisableDirPage=yes
DisableProgramGroupPage=yes
UninstallDisplayName=Girafon
UninstallDisplayIcon={app}\Girafon.exe
OutputDir={#OutputDirectory}
OutputBaseFilename=Girafon-Setup
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
english.Arm64WindowsVersionRequired=Girafon requires Windows 11 or later on ARM64 computers.
french.Arm64WindowsVersionRequired=Girafon nécessite Windows 11 ou une version ultérieure sur les ordinateurs ARM64.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#X64AppDirectory}\*"; DestDir: "{app}"; Check: not IsArm64; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#Arm64AppDirectory}\*"; DestDir: "{app}"; Check: IsArm64; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{userprograms}\Girafon"; Filename: "{app}\Girafon.exe"; WorkingDir: "{app}"
Name: "{userdesktop}\Girafon"; Filename: "{app}\Girafon.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\Girafon.exe"; Description: "{cm:LaunchProgram,Girafon}"; Flags: nowait postinstall skipifsilent

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
