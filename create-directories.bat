@echo off
mkdir c:\Projects\hotdesk\specs\001-desk-reservation-system\checklists
if %errorlevel% equ 0 (
    echo Directories created successfully
    dir c:\Projects\hotdesk\specs
) else (
    echo Error creating directories
    exit /b 1
)
