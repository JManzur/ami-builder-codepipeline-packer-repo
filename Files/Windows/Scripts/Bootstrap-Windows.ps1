if (-not (Test-Path C:\Temp)) {
    New-Item -Path "C:\" -Name Temp -ItemType directory
}

try
{
    $ErrorActionPreference = "Stop"
    Write-Host "INFO: Install Windows Activation Service"
    Install-WindowsFeature WAS
    Set-Service -Name 'WAS' -StartupType 'Automatic'

    Write-Host "INFO: Disable Windows Defender"
    [microsoft.win32.registry]::SetValue('HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection\', 'DisableRealtimeMonitoring', 1, [Microsoft.Win32.RegistryValueKind]::DWORD)
    [microsoft.win32.registry]::SetValue('HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet\', 'SpynetReporting', 0, [Microsoft.Win32.RegistryValueKind]::DWORD)
    [microsoft.win32.registry]::SetValue('HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet\', 'SubmitSamplesConsent', 2, [Microsoft.Win32.RegistryValueKind]::DWORD)

    Write-Host "INFO: Disable Defender Firewall"
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
}

catch
{
    Write-Error $_.Exception.Message
    exit 1
}