@echo off
title USB Password Vault

:: Define the USB drive serial number
set "expected_serial=1505-8763"
set retries=0

:: Function to detect connected USB devices
:detect_usb
set /a retries+=1
if %retries% geq 5 (
    echo Maximum retries reached. Exiting...
    pause
    exit /b
)

echo Scanning for USB devices...
for /f "tokens=2 delims==" %%a in ('wmic logicaldisk where "DriveType=2" get DeviceID /value') do (
    set usb_drive=%%a
    for /f "tokens=5" %%b in ('vol %%a') do (
        if "%%b"=="%expected_serial%" (
            echo Correct USB drive detected: %%a
            set found_usb=1 
            
            :: Disable AutoPlay for all removable drives
            reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" /v DisableAutoplay /t REG_DWORD /d 1 /f
            
            goto password_protect
        )
    )
)

if not defined found_usb (
    echo No matching USB device detected. Please insert the correct USB device and try again.
    pause
    cls
    goto detect_usb
)

:: Password protection for accessing the vault
:password_protect
set password=secret123
echo.
for /f "tokens=*" %%a in ('powershell -NoProfile -ExecutionPolicy Bypass -File get_password.ps1') do set input_password=%%a
if "%input_password%"=="%password%" (
    echo Access granted.
    pause
    cls
    goto vault_operations
) else (
    echo Access denied. Incorrect password.
    pause
    exit /b
)
:: Vault Operations (Store/Retrieve)
:vault_operations
cls
echo Welcome to the USB Vault!
echo [1] Store a password in the vault
echo [2] Retrieve passwords from the vault
echo [3] Run Scan
echo [4] Exit
set /p choice=Please select an option (1, 2, 3, or 4): 

if "%choice%"=="1" goto store_password
if "%choice%"=="2" goto retrieve_password
if "%choice%"=="3" goto run_scan
if "%choice%"=="4" exit

:: Store a password (Plain text)
:store_password
cls
echo Please enter the name of the account or service (e.g., Email, Bank):
set /p account_name=

if "%account_name%"=="" (
    echo Account name cannot be empty.
    pause
    goto store_password
)

echo Please enter the email address associated with %account_name%:
set /p email_address=

if "%email_address%"=="" (
    echo Email address cannot be empty.
    pause
    goto store_password
)

echo Please enter the password for %account_name%:
set /p account_password=

if "%account_password%"=="" (
    echo Password cannot be empty.
    pause
    goto store_password
)

:: Ensure Vault directory exists
if not exist "%usb_drive%\Vault" (
    mkdir "%usb_drive%\Vault"
)

:: Store the account information (account name, email, and password) in plain text
echo %account_name%:%email_address%:%account_password% >> "%usb_drive%\Vault\passwords.txt"
echo Password stored successfully!
pause
goto vault_operations

:: Retrieve a password (Plain text)
:retrieve_password
cls
echo Retrieving passwords stored in the vault...

if exist "%usb_drive%\Vault\passwords.txt" (
    for /f "tokens=1,2,3 delims=:" %%a in (%usb_drive%\Vault\passwords.txt) do (
        echo Account: %%a
        echo Email: %%b
        echo Password: %%c
        echo --------------------------
    )
) else (
    echo No passwords stored in the vault.
)

pause
goto vault_operations

:: Open Windows Security Virus & Threat Protection section
:run_scan
cls
echo Starting security scan...

:: Ensure whitelist.txt exists in the correct location
if not exist "%usb_drive%\Vault\whitelist.txt" (
    echo Whitelist file not found. Skipping whitelist check.
) else (
    :: Create a list of all active processes and exclude those in the whitelist
    tasklist > active_processes.txt
    for /f "tokens=1" %%a in (%usb_drive%\Vault\whitelist.txt) do (
        findstr /v /i "%%a" active_processes.txt > temp.txt
        move /y temp.txt active_processes.txt
    )

    :: Now the remaining processes in active_processes.txt are not in the whitelist
    findstr /v /i /g:%usb_drive%\Vault\whitelist.txt active_processes.txt > suspicious_processes.txt
)

:: Capture network connections
netstat > network_connections.txt

:: Write scan report
echo Scan completed on %date% at %time% > scan_report.txt
echo =============================== >> scan_report.txt
type suspicious_processes.txt >> scan_report.txt
echo ------------------------------- >> scan_report.txt
type network_connections.txt >> scan_report.txt

:: Display the scan report on the prompt
echo Scan report:
echo ===============================
type scan_report.txt
echo ===============================

pause
cls
goto vault_operations