ping -n 1 127.0.0.1 | find "TTL=" >nul 
if errorlevel 1 ( 
    echo   
) else (
    PowerShell.exe -ExecutionPolicy Bypass -File getChromEx-All.ps1
)
