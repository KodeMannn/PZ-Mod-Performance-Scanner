@echo off
title Project Zomboid Mod Performance Diagnostic Scanner
echo =================================================================
echo    PROJECT ZOMBOID MOD PERFORMANCE ^& STUTTER DIAGNOSTIC SCANNER
echo =================================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Scan-PZModPerformance.ps1"
echo.
pause
