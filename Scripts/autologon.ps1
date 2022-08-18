# powershell.exe -noprofile -executionpolicy bypass -file "%ScriptRoot%\autologon.ps1"
# Load MDT Task Sequence Environment and Logs
$TSenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
$logPath = $tsenv.Value("LogPath")
$logFile = "$logPath\$($myInvocation.MyCommand).log"
# Pour test en local
#$LogFile = "LogFile.log"
# Start the logging 
Write-Output "Logging to $logFile." > $logFile

Write-Output "Forces the workstation to logon AND allow to logon as a different user" >> $logFile
Try{
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name ForceAutoLogon -Type String -Value 1 -Force -ErrorAction Stop
}
Catch{
Write-Output $Error[0].Exception.Message >> $logFile
}

# Forces the workstation to logon AND disallow to logon as a different user ? Bypass holding shift key
#Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name ForceUnlockLogon -Type REG_DWORD -Value 1 -Force
#Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name ForceUnlockLogon -Type REG_DWORD -Value 1 -Force

Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name ForceUnlockLogon -Type DWORD -Value 1 -Force 



# Automatic logon for a user
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoAdminLogon -Type String -Value 1 -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultUserName -Type String -Value "User" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultPassword -Type String -Value "" -Force

Write-Output "Set 'User' as last logged in user" >> $logFile
Try{
$username='User'
$user = New-Object System.Security.Principal.NTAccount($username) 
$SID = $user.Translate([System.Security.Principal.SecurityIdentifier]) 
$SID.Value
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" -Name LastLoggedOnUserSID -Type String -Value $SID.Value -Force -ErrorAction Stop
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" -Name LastLoggedOnSAMUser -Type String -Value ".\User" -Force -ErrorAction Stop
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" -Name LastLoggedOnUser -Type String -Value ".\User" -Force -ErrorAction Stop
}
Catch{
Write-Output $Error[0].Exception.Message >> $logFile
}