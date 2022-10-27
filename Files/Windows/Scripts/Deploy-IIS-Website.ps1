if (-not (Test-Path C:\Temp)) {
    New-Item -Path "C:\" -Name Temp -ItemType directory
}

if (-not (Test-Path C:\AppWebsite)) {
    New-Item -Path "C:\" -Name AppWebsite -ItemType directory
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
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
	Install-Module -Name 'IISAdministration' -Force
	New-IISSite -Name 'AppWebsite' -PhysicalPath 'C:\AppWebsite\' -BindingInformation "*:8882:" -Force
    Set-WebConfigurationProperty -filter /system.webServer/directoryBrowse -name enabled -value true -PSPath 'IIS:\Sites\AppWebsite'
    New-WebApplication -Name "status" -Site "AppWebsite" -PhysicalPath "C:\AppWebsite\status" -ApplicationPool "DefaultAppPool" -Force
    Add-WebConfigurationProperty -Filter "//defaultDocument/files" -PSPath "IIS:\sites\AppWebsite\status" -AtIndex 0 -Name "Collection" -Value "status.json" -Force
	IISReset
}

catch
{
    Write-Error $_.Exception.Message
    exit 1
}