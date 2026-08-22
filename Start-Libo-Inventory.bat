@echo off
title Libo Inventory

echo ==========================================
echo          LIBO INVENTORY
echo ==========================================
echo.
echo Searching for R...
echo.

set "RSCRIPT="

for /d %%R in ("%ProgramFiles%\R\R-*") do (
    if exist "%%R\bin\Rscript.exe" set "RSCRIPT=%%R\bin\Rscript.exe"
)

if not defined RSCRIPT (
    echo ERROR: R was not found.
    echo.
    echo Please install R from:
    echo https://cran.r-project.org/
    echo.
    pause
    exit /b 1
)

echo R found:
echo %RSCRIPT%
echo.
echo Starting Libo Inventory...
echo.

"%RSCRIPT%" "%~dp0run.R"

pause