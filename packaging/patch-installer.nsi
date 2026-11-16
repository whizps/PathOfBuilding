Unicode true
SetCompressor /SOLID lzma
RequestExecutionLevel user

!include "MUI2.nsh"
!include "LogicLib.nsh"

!ifndef VERSION
	!define VERSION "dev"
!endif
!ifndef PAYLOAD
	!define PAYLOAD "payload"
!endif
!ifndef OUTFILE
	!define OUTFILE "PoB-Atlas-Tab-Setup-${VERSION}.exe"
!endif

Name "Atlas Tab for Path of Building"
OutFile "${OUTFILE}"
InstallDir "$APPDATA\Path of Building Community"
BrandingText "Atlas Tab ${VERSION}"
ShowInstDetails show
ShowUninstDetails show

!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "Atlas Tab for Path of Building"
!define MUI_WELCOMEPAGE_TEXT "This adds an Atlas tab to your existing Path of Building Community install, for planning atlas passive trees next to your builds.$\r$\n$\r$\nBefore you continue:$\r$\n$\r$\n  - Close Path of Building.$\r$\n  - Path of Building must already be installed.$\r$\n$\r$\nImportant: Path of Building's own updater replaces the files this patch changes. After every Path of Building update the Atlas button disappears. Run this installer again to bring it back. Your saved atlas trees are not lost as long as you don't save the build while the Atlas tab is missing.$\r$\n$\r$\nClick Next to continue."
!insertmacro MUI_PAGE_WELCOME

!define MUI_DIRECTORYPAGE_TEXT_TOP "Select your Path of Building folder: the folder that contains 'Path of Building.exe'.$\r$\n$\r$\nThe standard installer uses:$\r$\n    %APPDATA%\Path of Building Community$\r$\n$\r$\nFor the portable version, pick the folder you unzipped it into."
!define MUI_DIRECTORYPAGE_TEXT_DESTINATION "Path of Building folder"
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE VerifyPoBFolder
!insertmacro MUI_PAGE_DIRECTORY

!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_TITLE "Atlas tab installed"
!define MUI_FINISHPAGE_TEXT "Start Path of Building, open a build and click the Atlas button (next to Party and Compare).$\r$\n$\r$\nAfter a Path of Building update, run this installer again.$\r$\n$\r$\nTo remove the Atlas tab, run 'Uninstall Atlas Tab.exe' in the AtlasTab folder inside your Path of Building folder."
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Function VerifyPoBFolder
	${If} ${FileExists} "$INSTDIR\Launch.lua"
	${OrIf} ${FileExists} "$INSTDIR\src\Launch.lua"
		Return
	${EndIf}
	MessageBox MB_ICONEXCLAMATION|MB_OK "Path of Building was not found in:$\r$\n$INSTDIR$\r$\n$\r$\nPick the folder that contains 'Path of Building.exe'."
	Abort
FunctionEnd

Section "Atlas Tab"
	InitPluginsDir
	SetOutPath "$PLUGINSDIR\patch"
	File "install.ps1"
	SetOutPath "$PLUGINSDIR\patch\payload"
	File /r "${PAYLOAD}/*"
	DetailPrint "Patching Path of Building in $INSTDIR"
	nsExec::ExecToLog 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\patch\install.ps1" -PoBDir "$INSTDIR" -PayloadDir "$PLUGINSDIR\patch\payload"'
	Pop $0
	${If} $0 != 0
		SetDetailsView show
		MessageBox MB_ICONSTOP|MB_OK "The Atlas tab could not be installed. See the details above.$\r$\n$\r$\nNothing in Path of Building was changed."
		Abort
	${EndIf}
	${If} ${FileExists} "$INSTDIR\src\Launch.lua"
		StrCpy $1 "$INSTDIR\src\AtlasTab"
	${Else}
		StrCpy $1 "$INSTDIR\AtlasTab"
	${EndIf}
	SetOutPath "$1"
	File "install.ps1"
	File "${PAYLOAD}/hooks.json"
	WriteUninstaller "$1\Uninstall Atlas Tab.exe"
SectionEnd

Section "Uninstall"
	${If} ${FileExists} "$INSTDIR\..\Launch.lua"
		nsExec::ExecToLog 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$INSTDIR\install.ps1" -PoBDir "$INSTDIR\.." -PayloadDir "$INSTDIR" -Uninstall'
		Pop $0
		${If} $0 != 0
			MessageBox MB_ICONSTOP|MB_OK "The Atlas tab could not be removed cleanly. See the details above."
		${EndIf}
	${EndIf}
	Delete "$INSTDIR\install.ps1"
	Delete "$INSTDIR\hooks.json"
	Delete "$INSTDIR\version.txt"
	Delete "$INSTDIR\Uninstall Atlas Tab.exe"
	RMDir /r "$INSTDIR\backup"
	RMDir "$INSTDIR"
SectionEnd
