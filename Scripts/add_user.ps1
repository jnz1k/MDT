#Requires -RunAsAdministrator
#Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
#Set-ExecutionPolicy RemoteSigned -Force -Confirm:$true
# powershell.exe -noprofile -executionpolicy bypass -file "%ScriptRoot%\user.ps1"
# Add User, Disable UDP RDP

#User Add
net user "User" "" /add /fullname:"User"
net localgroup "Пользователи" "User" /add
WMIC USERACCOUNT WHERE "Name='User'" SET PasswordExpires=FALSE
WMIC USERACCOUNT WHERE "Name='User'" SET Passwordchangeable=FALSE

#Autologon
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$DefaultUsername = "User"
$DefaultPassword = ""
Set-ItemProperty $RegPath "AutoAdminLogon" -Value "1" -type String 
Set-ItemProperty $RegPath "DefaultUsername" -Value "$DefaultUsername" -type String 
Set-ItemProperty $RegPath "DefaultPassword" -Value "$DefaultPassword" -type String

#Disable UDP/Terminal
reg add "HKLM\software\policies\microsoft\windows nt\Terminal Services\Client" /v fClientDisableUDP /d 1 /t REG_DWORD