if (-not (Test-Path C:\Temp)) {
    New-Item -Path "C:\" -Name Temp -ItemType directory
}

try
{
    $ErrorActionPreference = "Stop"

    Write-Host "INFO: Installing IIS"
    Add-WindowsFeature Web-Server
    Add-WindowsFeature -IncludeAllSubFeature Web-Http-Redirect, Web-App-Dev, Web-Security, Web-Performance, Web-Mgmt-Tools, Web-Request-Monitor, Web-ODBC-Logging

	Write-Host "INFO: Disabling Windows Firewall"
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

	Write-Host "INFO: Deploying Website"
    # Set a custom ID in the index.html and status.json files
    [string]$ID = Get-Random
    $IndexDotHTML = "C:\AppWebsite\index.html"
    $IndexData = Get-Content $IndexDotHTML
    $IndexData = $IndexData.Replace('IDPlaceHolder', $ID)
    $IndexData | Out-File -encoding ASCII $IndexDotHTML
    $StatusDotJSON = "C:\AppWebsite\status\status.json"
    $StatusData = Get-Content $StatusDotJSON
    $StatusData = $StatusData.Replace('IDPlaceHolder', $ID)
    $StatusData | Out-File -encoding ASCII $StatusDotJSON
    # Deploy the website
	Install-Module -Name 'IISAdministration'
	New-Item -ItemType Directory -Name 'AppWebsite' -Path 'C:\'
	New-IISSite -Name 'AppWebsite' -PhysicalPath 'C:\AppWebsite\' -BindingInformation "*:8882:"
    New-WebApplication -Name "status" -Site "AppWebsite" -PhysicalPath "C:\AppWebsite\status.html" -ApplicationPool "AppWebsite"
    Add-WebConfigurationProperty -Filter "//defaultDocument/files" -PSPath "IIS:\sites\AppWebsite\status" -AtIndex 0 -Name "Collection" -Value "status.json"
	IISReset
}

catch
{
    Write-Error $_.Exception.Message
    exit 1
}