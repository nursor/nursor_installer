; Nursor App Installer Script
; This script is designed to create an installer for a Flutter Windows application.
; It handles:
; 1. Packaging all application files.
; 2. Moving wintun.dll to C:\Windows\System32.
; 3. Installing and trusting ca.pem certificate.
; 4. Creating start menu and optional desktop shortcuts.

#define MyAppName "Nursor App"
#define MyAppVersion "1.0.0"  ; <<-- This will be replaced by CI/CD
#define MyAppPublisher "Nursor.org"
#define MyAppURL "https://nursor.org"
#define MyAppExeName "nursor_app.exe"
#define MySourcePath "."  ; <<-- CI/CD will set this to the build directory
#define MyIconPath "logo.ico"  ; <<-- Icon should be in MySourcePath directory
#define GUID "{B7C211E6-630D-4C92-8065-D18C33AA7BE1}" ; <<-- IMPORTANT: This GUID should be unique for your app.

[Setup]
; Unique application identifier. DO NOT reuse this GUID for other applications.
; You can generate a new GUID using Tools -> Generate GUID in Inno Setup IDE.
AppId={{#GUID}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
; Default installation directory (e.g., C:\Program Files\Nursor App)
DefaultDirName={autopf}\{#MyAppName}
; Prevents the "Select Program Group" page from appearing
DisableProgramGroupPage=yes
; Installer requires administrator privileges for System32 file placement and certificate installation
PrivilegesRequired=admin
; Output filename of the generated installer executable
OutputBaseFilename=NursorInstaller
; Path to the installer's icon file (must be .ico format)
SetupIconFile={#MyIconPath}
; Compression method for the installer
Compression=lzma
; Enables solid compression for better compression ratio
SolidCompression=yes
; Sets the visual style of the installer wizard
WizardStyle=modern

[Tasks]
; Defines a task for creating a desktop shortcut.
; The user will see a checkbox for this option during installation.
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}";

[Files]
; --- Main application files ---
; All files within the 'windows' directory (except wintun.dll and ca.pem which are handled separately)
; and the entire 'data' subdirectory structure.
Source: "{#MySourcePath}\nursor_app.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MySourcePath}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MySourcePath}\nursor-core-amd64.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MySourcePath}\nursorcore_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MySourcePath}\screen_retriever_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MySourcePath}\tray_manager_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MySourcePath}\window_manager_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MySourcePath}\wintun.dll"; DestDir: "{app}"; Flags: ignoreversion
; Copies the entire 'data' folder and its contents recursively
Source: "{#MySourcePath}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; --- wintun.dll handling ---
; Copies wintun.dll to the System32 directory ({sys}).
; 'uninsneveruninstall' ensures it's not removed on uninstallation as other apps might use it.
Source: "{#MySourcePath}\wintun.dll"; DestDir: "{sys}"; Flags: ignoreversion uninsneveruninstall

; --- ca.pem handling ---
; Copies ca.pem to a temporary directory ({tmp}).
; 'deleteafterinstall' ensures it's removed from the temporary directory after certificate installation.
Source: "{#MySourcePath}\ca.pem"; DestDir:"{tmp}"; Flags: deleteafterinstall

[Icons]
; Creates a shortcut in the Start Menu Programs folder. This is typically always created.
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
; Creates a desktop shortcut IF the 'desktopicon' task is selected by the user.
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; --- Certificate Installation (ca.pem) ---
; Uses certutil.exe to add and trust the ca.pem certificate to various certificate stores.
; 'runhidden' prevents a command prompt window from appearing.
Filename: "certutil.exe"; Parameters: "-addstore -f ""Root"" ""{tmp}\ca.pem"""; StatusMsg: "正在安装并信任根证书..."; Flags: runhidden
Filename: "certutil.exe"; Parameters: "-addstore -f ""AuthRoot"" ""{tmp}\ca.pem"""; StatusMsg: "正在安装并信任认证根证书..."; Flags: runhidden
Filename: "certutil.exe"; Parameters: "-addstore -f ""TrustedPublisher"" ""{tmp}\ca.pem"""; StatusMsg: "正在安装并信任受信任发布者证书..."; Flags: runhidden

; --- Launch Application ---
; Launches the application after successful installation.
; 'nowait' means the installer doesn't wait for the app to close before finishing.
; 'postinstall' means it runs after all files are installed.
; 'skipifsilent' means it won't run if the installer is run silently.
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[Messages]
; Custom message for the setup confirmation page
SetupConfirmation=您即将安装 {#MyAppName} 版本 {#MyAppVersion}。点击“安装”继续。

[UninstallRun]
; --- Certificate Uninstallation (Optional) ---
; This command attempts to delete the ca.pem certificate from the 'Root' store upon uninstallation.
; Use with caution: Often, root certificates are left on the system unless specifically requested
; to avoid breaking other applications that might rely on them.
Filename: "certutil.exe"; Parameters: "-delstore ""Root"" ""{tmp}\ca.pem"""; StatusMsg: "正在卸载根证书..."; Flags: runhidden