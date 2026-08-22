@echo off
title Libo Inventory - Installation

echo ==========================================
echo       LIBO INVENTORY INSTALLER
echo ==========================================
echo.
echo Searching for R...
echo.

set "RSCRIPT="

for /d %%R in ("%ProgramFiles%\R\R-*") do (
    if exist "%%R\bin\Rscript.exe" set "RSCRIPT=%%R\bin\Rscript.exe"
)

if not defined RSCRIPT (
    echo ERROR: R was not found on this computer.
    echo.
    echo Please install R first.
    echo.
    echo Download R from:
    echo https://cran.r-project.org/
    echo.
    pause
    exit /b 1
)

echo R found:
echo %RSCRIPT%
echo.
echo Installing required R packages...
echo.
echo Please wait...
echo.

"%RSCRIPT%" "%~dp0scripts\install.R"

if errorlevel 1 (
    echo.
    echo ==========================================
    echo Installation encountered an error.
    echo ==========================================
    echo.
    pause
    exit /b 1
)

echo.
echo ==========================================
echo Installation completed successfully!
echo ==========================================
echo.
echo You can now double-click:
echo Start-Libo-Inventory.bat
echo.
pause