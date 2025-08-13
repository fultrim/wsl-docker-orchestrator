@echo off
wsl -d Ubuntu-Dev docker %* 2>&1
set EXITCODE=%ERRORLEVEL%
exit /b %EXITCODE%
