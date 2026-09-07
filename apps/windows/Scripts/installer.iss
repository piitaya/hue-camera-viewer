#ifndef AppDirectory
  #error Run package.ps1 to compile the installer.
#endif

[Setup]
AppId={{ADB72C20-A36B-497A-9876-47A9D381EC49}
AppName=Hue
AppVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\Hue
PrivilegesRequired=lowest
DisableDirPage=yes
DisableProgramGroupPage=yes
UninstallDisplayName=Hue
UninstallDisplayIcon={app}\Hue.exe
OutputDir={#OutputDirectory}
OutputBaseFilename=Hue-Setup-{#AppArchitecture}
SetupIconFile={#SetupIconPath}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
LanguageDetectionMethod=uilanguage
ShowLanguageDialog=no
CloseApplications=yes
RestartApplications=no
#if AppArchitecture == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
MinVersion=10.0.22000
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19041
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#AppDirectory}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{userprograms}\Hue"; Filename: "{app}\Hue.exe"; WorkingDir: "{app}"
Name: "{userdesktop}\Hue"; Filename: "{app}\Hue.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\Hue.exe"; Description: "{cm:LaunchProgram,Hue}"; Flags: nowait postinstall skipifsilent
