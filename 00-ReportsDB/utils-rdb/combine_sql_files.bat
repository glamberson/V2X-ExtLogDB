@echo off
setlocal

rem Input file list
set file_list=file_list.txt
rem Output file
set output_file=combined_script.sql

rem Check if the file list exists
if not exist %file_list% (
    echo File list not found: %file_list%
    endlocal
    pause
    exit /b 1
)

rem Remove the output file if it already exists
if exist %output_file% del %output_file%

rem Read the file list and concatenate the files
for /f "delims=" %%i in (%file_list%) do (
    echo -- Including %%i >> %output_file%
    type "%%i" >> %output_file%
    echo. >> %output_file%
    echo. >> %output_file%
)

echo Combined script created: %output_file%
endlocal
pause
