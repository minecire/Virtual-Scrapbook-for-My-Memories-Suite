;!include "installer.nsh"

!define NAME "Virtual Scrapbook"
!define REGPATH_UNINSTSUBKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${NAME}"
Name "${NAME}"
OutFile "Install ${NAME}.exe"
Unicode True
RequestExecutionLevel Admin ; Request admin rights on WinVista+ (when UAC is turned on)
InstallDir "$ProgramFiles\$(^Name)"
InstallDirRegKey HKLM "${REGPATH_UNINSTSUBKEY}" "UninstallString"
Icon "Virtual Scrapbook Icon.ico"

!include LogicLib.nsh
!include Integration.nsh


Page Directory
Page InstFiles

Uninstpage UninstConfirm
Uninstpage InstFiles


!macro EnsureAdminRights
  UserInfo::GetAccountType
  Pop $0
  ${If} $0 != "admin" ; Require admin rights on WinNT4+
    MessageBox MB_IconStop "Administrator rights required!"
    SetErrorLevel 740 ; ERROR_ELEVATION_REQUIRED
    Quit
  ${EndIf}
!macroend

Function .onInit
  SetShellVarContext All
  !insertmacro EnsureAdminRights
FunctionEnd

Function un.onInit
  SetShellVarContext All
  !insertmacro EnsureAdminRights
FunctionEnd


Section "Program files (Required)"
  SectionIn Ro



  SetOutPath $InstDir

  File "${NAME}.exe"

  WriteUninstaller "$InstDir\Uninst.exe"
  WriteRegStr HKLM "${REGPATH_UNINSTSUBKEY}" "DisplayName" "${NAME}"
  WriteRegStr HKLM "${REGPATH_UNINSTSUBKEY}" "DisplayIcon" "$InstDir\${NAME}.exe,0"
  WriteRegStr HKLM "${REGPATH_UNINSTSUBKEY}" "UninstallString" '"$InstDir\Uninst.exe"'
  WriteRegStr HKLM "${REGPATH_UNINSTSUBKEY}" "QuietUninstallString" '"$InstDir\Uninst.exe" /S'
  WriteRegDWORD HKLM "${REGPATH_UNINSTSUBKEY}" "NoModify" 1
  WriteRegDWORD HKLM "${REGPATH_UNINSTSUBKEY}" "NoRepair" 1


  
SectionEnd

Section "Start Menu shortcut"
  CreateShortcut /NoWorkingDir "$SMPrograms\${NAME}.lnk" "$InstDir\${NAME}.exe"
SectionEnd


!macro DeleteFileOrAskAbort path
  ClearErrors
  Delete "${path}"
  IfErrors 0 +3
    MessageBox MB_ABORTRETRYIGNORE|MB_ICONSTOP 'Unable to delete "${path}"!' IDRETRY -3 IDIGNORE +2
    Abort "Aborted"
!macroend

Section -Uninstall
  !insertmacro DeleteFileOrAskAbort "$InstDir\${NAME}.exe"
  !insertmacro DeleteFileOrAskAbort "$InstDir\${NAME}.pck"
  Delete "$InstDir\Uninst.exe"
  RMDir "$InstDir"
  DeleteRegKey HKLM "${REGPATH_UNINSTSUBKEY}"

  ${UnpinShortcut} "$SMPrograms\${NAME}.lnk"
  Delete "$SMPrograms\${NAME}.lnk"
SectionEnd


!define ASSOC_EXT ".vsb"
!define ASSOC_PROGID "Virtual.Scrapbook"
!define ASSOC_VERB "VirtualScrapbook"
!define ASSOC_APPEXE "${NAME}.exe"
!define APP_NAME "Virtual Scrapbook"
Section -ShellAssoc
  # Register file type
  WriteRegStr ShCtx "Virtual Scrapbook Icon.ico" "" "$InstDir\${ASSOC_APPEXE},0"
  WriteRegStr ShCtx "Software\Classes\${ASSOC_PROGID}\shell\${ASSOC_VERB}" "" "${APP_NAME}"
  WriteRegStr ShCtx "Software\Classes\${ASSOC_PROGID}\shell\${ASSOC_VERB}" "MUIVerb" "@$InstDir\${ASSOC_APPEXE},-42" ; WinXP+ [Optional] Localizable verb display name
  WriteRegStr ShCtx "Software\Classes\${ASSOC_PROGID}\shell\${ASSOC_VERB}\command" "" '"$InstDir\${ASSOC_APPEXE}" "%1"'
  WriteRegStr ShCtx "Software\Classes\${ASSOC_EXT}" "" "${ASSOC_PROGID}"

  # Register "Open With" [Optional]
  WriteRegNone ShCtx "Software\Classes\${ASSOC_EXT}\OpenWithList" "${ASSOC_APPEXE}" ; Win2000+ [Optional]
  ;WriteRegNone ShCtx "Software\Classes\${ASSOC_EXT}\OpenWithProgids" "${ASSOC_PROGID}" ; WinXP+ [Optional]
  WriteRegStr ShCtx "Software\Classes\Applications\${ASSOC_APPEXE}\shell\open\command" "" '"$InstDir\${ASSOC_APPEXE}" "%1"'
  WriteRegStr ShCtx "Software\Classes\Applications\${ASSOC_APPEXE}" "FriendlyAppName" "${APP_NAME}" ; [Optional]
  WriteRegStr ShCtx "Software\Classes\Applications\${ASSOC_APPEXE}" "ApplicationCompany" "Nullsoft" ; [Optional]
  WriteRegNone ShCtx "Software\Classes\Applications\${ASSOC_APPEXE}\SupportedTypes" "${ASSOC_EXT}" ; [Optional] Only allow "Open With" with specific extension(s) on WinXP+

  # Register "Default Programs" [Optional]
  !ifdef REGISTER_DEFAULTPROGRAMS
  WriteRegStr ShCtx "Software\Classes\Applications\${ASSOC_APPEXE}\Capabilities" "ApplicationDescription" "Virtual Scrapbook Viewer"
  WriteRegStr ShCtx "Software\Classes\Applications\${ASSOC_APPEXE}\Capabilities\FileAssociations" "${ASSOC_EXT}" "${ASSOC_PROGID}"
  WriteRegStr ShCtx "Software\RegisteredApplications" "Virtual Scrapbook" "Software\Classes\Applications\${ASSOC_APPEXE}\Capabilities"
  !endif

  ${NotifyShell_AssocChanged}
SectionEnd


Section -un.ShellAssoc
  # Unregister file type
  ClearErrors
  DeleteRegKey ShCtx "Software\Classes\${ASSOC_PROGID}\shell\${ASSOC_VERB}"
  DeleteRegKey /IfEmpty ShCtx "Software\Classes\${ASSOC_PROGID}\shell"
  ${IfNot} ${Errors}
    DeleteRegKey ShCtx "Software\Classes\${ASSOC_PROGID}\DefaultIcon"
  ${EndIf}
  ReadRegStr $0 ShCtx "Software\Classes\${ASSOC_EXT}" ""
  DeleteRegKey /IfEmpty ShCtx "Software\Classes\${ASSOC_PROGID}"
  ${IfNot} ${Errors}
  ${AndIf} $0 == "${ASSOC_PROGID}"
    DeleteRegValue ShCtx "Software\Classes\${ASSOC_EXT}" ""
    DeleteRegKey /IfEmpty ShCtx "Software\Classes\${ASSOC_EXT}"
  ${EndIf}

  # Unregister "Open With"
  DeleteRegKey ShCtx "Software\Classes\Applications\${ASSOC_APPEXE}"
  DeleteRegValue ShCtx "Software\Classes\${ASSOC_EXT}\OpenWithList" "${ASSOC_APPEXE}"
  DeleteRegKey /IfEmpty ShCtx "Software\Classes\${ASSOC_EXT}\OpenWithList"
  DeleteRegValue ShCtx "Software\Classes\${ASSOC_EXT}\OpenWithProgids" "${ASSOC_PROGID}"
  DeleteRegKey /IfEmpty ShCtx "Software\Classes\${ASSOC_EXT}\OpenWithProgids"
  DeleteRegKey /IfEmpty  ShCtx "Software\Classes\${ASSOC_EXT}"

  # Unregister "Default Programs"
  !ifdef REGISTER_DEFAULTPROGRAMS
  DeleteRegValue ShCtx "Software\RegisteredApplications" "Nullsoft Test App"
  DeleteRegKey ShCtx "Software\Classes\Applications\${ASSOC_APPEXE}\Capabilities"
  DeleteRegKey /IfEmpty ShCtx "Software\Classes\Applications\${ASSOC_APPEXE}"
  !endif

  # Attempt to clean up junk left behind by the Windows shell
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Search\JumplistData" "$InstDir\${ASSOC_APPEXE}"
  DeleteRegValue HKCU "Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" "$InstDir\${ASSOC_APPEXE}.FriendlyAppName"
  DeleteRegValue HKCU "Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" "$InstDir\${ASSOC_APPEXE}.ApplicationCompany"
  DeleteRegValue HKCU "Software\Microsoft\Windows\ShellNoRoam\MUICache" "$InstDir\${ASSOC_APPEXE}" ; WinXP
  DeleteRegValue HKCU "Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" "$InstDir\${ASSOC_APPEXE}"
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts" "${ASSOC_PROGID}_${ASSOC_EXT}"
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts" "Applications\${ASSOC_APPEXE}_${ASSOC_EXT}"
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\${ASSOC_EXT}\OpenWithProgids" "${ASSOC_PROGID}"
  DeleteRegKey /IfEmpty HKCU "Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\${ASSOC_EXT}\OpenWithProgids"
  DeleteRegKey /IfEmpty HKCU "Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\${ASSOC_EXT}\OpenWithList"
  DeleteRegKey /IfEmpty HKCU "Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\${ASSOC_EXT}"
  ;DeleteRegKey HKCU "Software\Microsoft\Windows\Roaming\OpenWith\FileExts\${ASSOC_EXT}"
  ;DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs\${ASSOC_EXT}"

  ${NotifyShell_AssocChanged}
SectionEnd
