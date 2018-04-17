@echo off
setlocal

rem Change value "Find" to "Delete" to really delete all found keys.
set "Action=DELETE"

rem Define the root key for the search.
set "RegKey=HKEY_LOCAL_MACHINE\SOFTWARE"

rem Define the string which must be found in name of a key to delete.
rem It should not contain characters interpreted by FINDSTR as regular
rem expression character, see help output on entering FINDSTR /? in a
rem command prompt window.
set "Search=Azure"

rem Check if specified registry key exists at all.
%SystemRoot%\System32\reg.exe query "%RegKey%" 1>nul 2>nul
if not errorlevel 1 goto RunSearch

echo.
echo Registry key "%RegKey%" not found.
goto EndBatch

:RunSearch
rem Exporting everything of defined root key to a temporary text file.
echo Exporting registry key "%RegKey%" ...
%SystemRoot%\System32\reg.exe query "%RegKey%" /s >"%TEMP%\RegExport.tmp" 2>nul

rem The backslash is the escape character in regular expressions. Therefore
rem it is necessary to escape this character in root registry key to get a
rem working regular expression search string as long as the root registry
rem key and the search string do not contain other characters with special
rem registry expression meaning.
set "RegKey=%RegKey:\=\\%"

rem Interesting are only lines in exported registry which contain the
rem search string in last key of a registry key path. In other words
rem the deletion of a key is always done only on root key containing in
rem name the search string and not also on all subkeys to improve speed.

if /I "%Action%"=="Delete" (
    echo Searching for keys containing "%Search%" and delete all found ...
) else (
    echo Searching for keys containing "%Search%" and list all found ...
)

rem The expression below works only correct if whether RegKey nor
rem Search contains characters with a regular expression meaning.
set "FoundCounter=0"
set "DeleteCounter=0"
for /f "delims=" %%K in ('%SystemRoot%\System32\findstr.exe /R "^%RegKey%.*%Search%[^\\]*$" "%TEMP%\RegExport.tmp" 2^>nul') do (
    echo %%K
    set /A FoundCounter+=1
    if /I "%Action%"=="Delete" (
        %SystemRoot%\System32\reg.exe delete "%%K" /f >nul
        if not errorlevel 1 set /A "DeleteCounter+=1"
    )
)
del "%TEMP%\RegExport.tmp"

set "FoundPlural="
if not %FoundCounter%==1 set "FoundPlural=s"
set "DeletePlural="
if not %DeleteCounter%==1 set "DeletePlural=s"

echo.
if /I "%Action%"=="Delete" (
    echo Deleted %DeleteCounter% key%DeletePlural% of %FoundCounter% key%FoundPlural% containing "%Search%".
) else (
    echo Found %FoundCounter% key%FoundPlural% containing "%Search%".
)

:EndBatch
endlocal
echo.
exit 0