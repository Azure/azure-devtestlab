@echo off

rem This is required to ensure we don't get error 0x8024800C -2145091572 WU_E_DS_LOCKTIMEOUTEXPIRED The data store section could not be locked within the allotted time.
echo Cleaning software distribution folder.
net stop "Windows Update" >nul 2>&1
echo "Y" | del /f /s C:\Windows\SoftwareDistribution\ >nul 2>&1
net start "Windows Update" >nul 2>&1

if defined ProgramFiles(X86) (
    echo Applying Windows6.1-KB2506143-x64.msu
    call Windows6.1-KB2506143-x64.msu /quiet /norestart
) else (
    echo Applying Windows6.1-KB2506143-x86.msu
    call Windows6.1-KB2506143-x86.msu /quiet /norestart
)

if %ERRORLEVEL% equ 0 (
    goto EXIT
)
if %ERRORLEVEL% equ 1641 (
    echo The recent package changes indicate a reboot is necessary.
    goto RESTART
)
if %ERRORLEVEL% equ 3010 (
    echo The recent package changes indicate a reboot is necessary.
    goto RESTART
)
if %ERRORLEVEL% equ 2359302 (
    goto EXIT
)
goto EXIT_ERROR

:EXIT_ERROR
echo An error occured during artifact installation. Review the virtual machine logs for more details. (%ERRORLEVEL%)
exit %ERRORLEVEL%

:RESTART
rem Two restarts are required. This is the first one. The second one is defined in the postDeployActions of the artifactfile.json.
shutdown.exe /r /t 00

:EXIT
echo The artifact was applied successfully.
exit 0