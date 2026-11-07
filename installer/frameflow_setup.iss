; Inno Setup Script for FrameFlow Studio
#define MyAppName "FrameFlow Studio"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "FrameFlow Team"
#define MyAppExeName "frameflow.exe"

[Setup]
AppId={{E68F83A2-4BC2-4B2E-99F7-70C9A098F391}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
OutputDir=C:\Users\USER\Desktop
OutputBaseFilename=FrameFlow_Studio_Setup_v1.0.0
SetupIconFile=C:\Users\USER\Desktop\frameflow\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\assets\bin\ffmpeg.exe"; DestDir: "{app}\assets\bin"; Flags: ignoreversion
Source: "..\assets\bin\ffprobe.exe"; DestDir: "{app}\assets\bin"; Flags: ignoreversion
Source: "..\assets\bin\ffmpeg.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\assets\bin\ffprobe.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
