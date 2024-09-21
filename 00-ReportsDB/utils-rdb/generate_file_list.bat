@echo off
setlocal

rem Output file for the list of SQL files
set file_list=file_list.txt

rem Remove the output file if it already exists
if exist %file_list% del %file_list%

rem Find all .sql files and sort them alphanumerically
for /f "delims=" %%i in ('dir /b /s /o:n *.sql') do echo %%i >> %file_list%

echo File list created: %file_list%
endlocal
pause
