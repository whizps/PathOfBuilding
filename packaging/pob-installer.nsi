Unicode true
SetCompressor /SOLID lzma
SetCompressorDictSize 64
RequestExecutionLevel user

!include "MUI2.nsh"
!include "LogicLib.nsh"

!ifndef VERSION
	!define VERSION "dev"
!endif
!ifndef STAGE
	!define STAGE "stage"
!endif
!ifndef OUTFILE
	!define OUTFILE "PathOfBuilding-Atlas-Setup.exe"
!endif
!ifndef RELEASE_NAME
	!define RELEASE_NAME "${VERSION}"
!endif

!define APPNAME "Path of Building (Atlas)"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\PathOfBuildingAtlas"

Name "${APPNAME}"
OutFile "${OUTFILE}"
InstallDir "$APPDATA\Path of Building Atlas"
InstallDirRegKey HKCU "${UNINSTKEY}" "InstallLocation"
BrandingText "${RELEASE_NAME}"
ShowInstDetails nevershow
ShowUninstDetails nevershow

!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "${APPNAME}"
!define MUI_WELCOMEPAGE_TEXT "This installs Path of Building with the Atlas tab (${RELEASE_NAME}, based on Path of Building ${VERSION}).$\r$\n$\r$\nIt is installed next to the official Path of Building, which is not changed. Both share your builds and settings in Documents\Path of Building.$\r$\n$\r$\nUpdates arrive through the normal 'Update' button inside the program.$\r$\n$\r$\nClose Path of Building before continuing."
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\Path of Building.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Start ${APPNAME}"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Section "Path of Building"
	SetOutPath "$INSTDIR"
	File /r "${STAGE}/*"
	FileOpen $0 "$INSTDIR\installed.cfg" w
	FileClose $0
	WriteUninstaller "$INSTDIR\Uninstall.exe"
	CreateDirectory "$SMPROGRAMS\${APPNAME}"
	CreateShortCut "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" "$INSTDIR\Path of Building.exe"
	CreateShortCut "$SMPROGRAMS\${APPNAME}\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
	CreateShortCut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\Path of Building.exe"
	WriteRegStr HKCU "${UNINSTKEY}" "DisplayName" "${APPNAME}"
	WriteRegStr HKCU "${UNINSTKEY}" "DisplayVersion" "${RELEASE_NAME}"
	WriteRegStr HKCU "${UNINSTKEY}" "DisplayIcon" "$INSTDIR\Path of Building.exe"
	WriteRegStr HKCU "${UNINSTKEY}" "InstallLocation" "$INSTDIR"
	WriteRegStr HKCU "${UNINSTKEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
	WriteRegDWORD HKCU "${UNINSTKEY}" "NoModify" 1
	WriteRegDWORD HKCU "${UNINSTKEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
	Delete "$DESKTOP\${APPNAME}.lnk"
	RMDir /r "$SMPROGRAMS\${APPNAME}"
	DeleteRegKey HKCU "${UNINSTKEY}"
	${If} ${FileExists} "$INSTDIR\Path of Building.exe"
	${AndIf} ${FileExists} "$INSTDIR\Launch.lua"
		RMDir /r "$INSTDIR"
	${EndIf}
SectionEnd
