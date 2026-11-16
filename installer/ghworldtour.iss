; GHWorldTourRecomp's installer (Inno Setup 6.6 or later). tools\package-release.ps1 builds it
; from the staged Release Bundle:
;   ISCC /DAppVersion=0.1.0 /DSourceDir=<staging folder> /DOutputDir=<folder> installer\ghworldtour.iss
;
; - Installs only this project's files (the Release Bundle: executables, DLLs, pipeline list,
;   documents, licenses, assets\README.md). Game files come from the player's ISO on first launch.
; - Installs for the current user without admin rights under %LOCALAPPDATA%\Programs\GHWorldTourRecomp
;   so the game can write userdata\ and the launcher can self-update in place.
; - Upgrading over an existing installation preserves saves, settings, and game files.
; - Uninstalling prompts before deleting saves/settings or extracted game files.

#ifndef AppVersion
  #error Define AppVersion, SourceDir and OutputDir (see the top of this file)
#endif
#ifndef SourceDir
  #error Define SourceDir (see the top of this file)
#endif
#ifndef OutputDir
  #error Define OutputDir (see the top of this file)
#endif

#define AppName "Guitar Hero: World Tour"
#define ShortcutName "Guitar Hero - World Tour"
#define LauncherExe "GH World Tour Launcher.exe"
#define RepoUrl "https://github.com/zenthora/GHWorldTourRecomp"

; Strip any prerelease suffix (e.g. 0.1.0-beta.1 -> 0.1.0) for VersionInfoVersion.
#define FileVersion Copy(AppVersion, 1, Pos("-", AppVersion + "-") - 1)

[Setup]
; Never change AppId: Windows identifies this installation by it across upgrades.
AppId={{5D11D4B9-22BE-49BD-9305-720471B17018}
AppName={#AppName} (Recomp)
AppVersion={#AppVersion}
AppVerName={#AppName} (Recomp) {#AppVersion}
AppPublisher=zenthora
#if RepoUrl != ""
AppPublisherURL={#RepoUrl}
AppSupportURL={#RepoUrl}/issues
AppUpdatesURL={#RepoUrl}/releases
#endif
VersionInfoVersion={#FileVersion}.0
VersionInfoDescription={#AppName} (Recomp) setup
PrivilegesRequired=lowest
DefaultDirName={autopf}\GHWorldTourRecomp
DisableProgramGroupPage=yes
DisableWelcomePage=no
UninstallDisplayName={#AppName} (Recomp)
UninstallDisplayIcon={app}\{#LauncherExe}
#if FileExists(AddBackslash(SourcePath) + "..\res\icon.ico")
SetupIconFile=..\res\icon.ico
#endif
WizardStyle=modern dark
WizardImageFile=wizard-202x386.png,wizard-336x643.png,wizard-430x824.png
WizardSmallImageFile=small-58.png,small-97.png,small-124.png
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
CloseApplications=yes
RestartApplications=no
Compression=lzma2/max
SolidCompression=yes
OutputDir={#OutputDir}
OutputBaseFilename=GHWorldTourRecomp-v{#AppVersion}-setup
ShowLanguageDialog=auto

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Messages]
english.WelcomeLabel2=This will install [name/ver] on your computer.%n%nYou need your own copy of the game: the first time the launcher opens, it asks for the ISO of your Xbox 360 disc and extracts the game's files from it.
spanish.WelcomeLabel2=Este programa instalará [name/ver] en su sistema.%n%nNecesita su propia copia del juego: la primera vez que se abra, el launcher le pedirá la ISO de su disco de Xbox 360 y extraerá de ella los archivos del juego.
german.WelcomeLabel2=Dieser Assistent wird jetzt [name/ver] auf Ihrem Computer installieren.%n%nSie benötigen Ihre eigene Kopie des Spiels: Beim ersten Start fragt der Launcher nach der ISO Ihrer Xbox-360-Disc und extrahiert daraus die Spieldateien.
french.WelcomeLabel2=Cet assistant va vous guider dans l'installation de [name/ver] sur votre ordinateur.%n%nVous avez besoin de votre propre copie du jeu : à sa première ouverture, le launcher vous demandera l'ISO de votre disque Xbox 360 et en extraira les fichiers du jeu.
italian.WelcomeLabel2=[name/ver] sarà installato sul computer.%n%nServe la tua copia del gioco: la prima volta che si apre, il launcher ti chiederà la ISO del tuo disco Xbox 360 e ne estrarrà i file del gioco.

[CustomMessages]
english.DeleteUserData=Also delete your caches and settings?%n%nThey are in the game's folder (userdata and the .toml files). Choose No to keep them for a later installation.
spanish.DeleteUserData=¿Desea borrar también sus cachés y ajustes?%n%nEstán en la carpeta del juego (userdata y los archivos .toml). Elija No para conservarlos para una instalación futura.
german.DeleteUserData=Sollen auch Ihre Caches und Einstellungen gelöscht werden?%n%nSie liegen im Ordner des Spiels (userdata und die .toml-Dateien). Wählen Sie Nein, um sie für eine spätere Installation zu behalten.
french.DeleteUserData=Supprimer aussi vos caches et réglages ?%n%nIls se trouvent dans le dossier du jeu (userdata et les fichiers .toml). Choisissez Non pour les garder pour une installation ultérieure.
italian.DeleteUserData=Eliminare anche cache e impostazioni?%n%nSi trovano nella cartella del gioco (userdata e i file .toml). Scegli No per conservarli per un'installazione futura.
english.DeleteGameFiles=Also delete the game files extracted from your disc (the assets folder, 6.3 GB)?%n%nTo play again, you would need your ISO.
spanish.DeleteGameFiles=¿Desea borrar también los archivos del juego extraídos de su disco (la carpeta assets, 6,3 GB)?%n%nPara volver a jugar necesitaría de nuevo su ISO.
german.DeleteGameFiles=Sollen auch die von Ihrer Disc extrahierten Spieldateien gelöscht werden (der Ordner assets, 6,3 GB)?%n%nUm wieder zu spielen, bräuchten Sie erneut Ihre ISO.
french.DeleteGameFiles=Supprimer aussi les fichiers du jeu extraits de votre disque (le dossier assets, 6,3 Go) ?%n%nPour rejouer, il vous faudrait à nouveau votre ISO.
italian.DeleteGameFiles=Eliminare anche i file del gioco estratti dal disco (la cartella assets, 6,3 GB)?%n%nPer giocare di nuovo servirà ancora la tua ISO.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#ShortcutName}"; Filename: "{app}\{#LauncherExe}"
Name: "{autodesktop}\{#ShortcutName}"; Filename: "{app}\{#LauncherExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#LauncherExe}"; Description: "{cm:LaunchProgram,{#ShortcutName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\update"
Type: files; Name: "{app}\update-leftovers.txt"
Type: files; Name: "{app}\*.old-update"
Type: files; Name: "{app}\*.exe"
Type: files; Name: "{app}\*.dll"
Type: files; Name: "{app}\*.pipelines.list"
Type: filesandordirs; Name: "{app}\licenses"
Type: filesandordirs; Name: "{app}\logs"

[Code]
var
  DeleteUserData: Boolean;
  DeleteGameFiles: Boolean;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  App: String;
begin
  App := ExpandConstant('{app}');
  if CurUninstallStep = usUninstall then
  begin
    DeleteUserData := False;
    DeleteGameFiles := False;
    if not UninstallSilent then
    begin
      if DirExists(App + '\userdata') or FileExists(App + '\ghworldtour_options.toml') or FileExists(App + '\ghworldtour.toml') then
        DeleteUserData := MsgBox(CustomMessage('DeleteUserData'), mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES;
      if FileExists(App + '\assets\default.xex') then
        DeleteGameFiles := MsgBox(CustomMessage('DeleteGameFiles'), mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES;
    end;
  end
  else if CurUninstallStep = usPostUninstall then
  begin
    if DeleteUserData then
    begin
      DelTree(App + '\userdata', True, True, True);
      DeleteFile(App + '\ghworldtour.toml');
      DeleteFile(App + '\ghworldtour_options.toml');
    end;
    if DeleteGameFiles then
      DelTree(App + '\assets', True, True, True);
    RemoveDir(App + '\assets');
    RemoveDir(App);
  end;
end;
