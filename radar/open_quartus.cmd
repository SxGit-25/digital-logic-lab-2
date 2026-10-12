@echo off
setlocal
if exist R:\constraints\radar.qpf goto launch
if exist R:\ (
  echo R: is already in use. Close this window and free drive R: first.
  pause
  exit /b 1
)
subst R: "%~dp0"
if errorlevel 1 (
  echo Failed to map the project folder to R:.
  pause
  exit /b 1
)
:launch
start "" "E:\quartus\QuartusII91\quartus\bin64\quartus.exe" "R:\constraints\radar.qpf"
endlocal
