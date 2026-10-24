@echo off
REM Create the spec directory
cd /d "c:\Projects\hotdesk"
if not exist "specs" mkdir specs
if not exist "specs\001-desk-reservation-system" mkdir specs\001-desk-reservation-system
echo Directory created successfully
