if (-not (Test-Path C:\Temp)) {
    New-Item -Path "C:\" -Name Temp -ItemType directory
}

try
{
    $ErrorActionPreference = "Stop"
    Write-Host "INFO: Install Windows Notepad++"
    Invoke-WebRequest https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.4/npp.8.4.Installer.x64.exe -OutFile C:\Temp\npp.8.4.Installer.x64.exe -UseBasicParsing
    Start-Process -FilePath C:\Temp\npp.8.4.Installer.x64.exe /S -NoNewWindow -Wait -PassThru
}

catch
{
    Write-Error $_.Exception.Message
    exit 1
}