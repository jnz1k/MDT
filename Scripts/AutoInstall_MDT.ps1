#Requires -Version 4
#Requires -RunAsAdministrator
<# This Script:       Niall Brady      - http://www.windows-noob.com
#                                      - November 14th, 2017.
#                     Derek Bannard    - http://www.stonywall.com
#                                      - February 14th, 2022.
#
#                     This script is customized for deploying Windows 11 Professional x64.
#		              The script downloads required files (if necessary) and then configures this server with:
# 
#                     * Windows ADK 11 (version 21H2)
#                     * Microsoft Deploymnet Toolkit (MDT) (latest will be downloaded incuding hotfix)
#                     * Surface Pro 8 drivers
#
#                     The script updates the deployment share and populates WDS
#                     with the MDT boot images before starting WDS.
#
#
# This script is fully automated. However should you want to pre-populate any applications, add them to
# the source folder location as referenced in $SourcePath.
#
#    [Required]       D:\Source
#
#
# Usage:              Copy the script to the server D:\ or within the "Source" folder if preferred.
#                     Copy your source files to the folder structure above, making note of what is [Optional] and what is [Required]       
#                     If you have already downloaded the SurfacePro drivers, ADK & MDT, copy the files to D:\Source            
#                     If the files do not exist in the folder D:\Source the script will download them for you. 
#                     Edit the variables in the script below to meet your needs and enjoy.
#
#                     This script contains code from other peoples fine work including:
#                     
#                     Nickolaj Andersen - http://www.scconfigmgr.com
#                     Chris Steding     - http://www.compit.se
#                     Brandon Linton    - http://blogs.technet.com/b/brandonlinton/
#                     Trevor Sullivan   - http://trevorsullivan.net/
#                     Derek Bannard     - http://stonywall.com/
#>
clear

  If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] “Administrator”))

    {
        Write-Warning “You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!”
        Break
    }

Write-Host "This scripts needs unrestricted access (Set-ExecutionPolicy Unrestricted)" -ForegroundColor Green
Write-Host "The entire setup takes around 10 minutes or less (depending on your internet speed and if components are already downloaded). " -nonewline -ForegroundColor Green
Write-Host "At the end of the process, if there are any errors they will be shown in " -nonewline -ForegroundColor Green
Write-Host "red text" -nonewline -ForegroundColor Red
Write-Host ". Review them to see what failed." -ForegroundColor Green
Write-Host " "


# Configurable Variables
$CompanyName = "Rosman";											# Company name used for OrgName in script. 
$Wks_AdminPwd = "Password";												# Password used for local Administrator account.

$MDT_Admin_is_Domain_Admin = "false";											# MDT admin domain account is part of the "Domain Administrators" AD group or not. Accepted values: true, false
$MDT_Admin = "User";														# MDT admin domain account used to join computers to the domain.
$MDT_AdminPwd = "Password";											# MDT admin domain account password.

$FolderPath = "C:\DeploymentShare";												# MDT installation folder.
$WDSPath = "C:\RemoteInstall";													# WDS installation folder.

# Sort-of-Configurable Variables
$ComputerName = $env:computerName;												# Full dns computer name.
$Domain_FQ = $env:userdnsdomain;												# Fully qualified domain name.
$Domain_NB = $env:userdomain;													# NETBIOS "short" domain name.

$Default_Computers_OU = "CN=Computers"+(($Env:USERDNSDOMAIN.Split('.')|%{(",DC=$_")})-join'');	# Sets the computer OU to the domains' default computer OU.
$WSUS_SVR = "WSUS"+('.'+($Env:USERDNSDOMAIN)+':8530');							# Host name of the WSUS server, without the FQDN domain name.

# Download the setup files manually for offline installation. Place within the source path listed below.
# Destination folder when downloading and launching programs and files within this script.
$SourcePath = "C:\Source"

# Surface Pro 8 drivers, for initial population
$DriverReleaseURL = "https://download.microsoft.com/download/9/1/3/9133dbd3-799a-4766-bb9e-f67697159c02/SurfacePro8_Win11_22000_22.011.9739.0.msi"

# ADK install
$ADKPath = '{0}\Windows Kits\10\ADK' -f $SourcePath;
$ADKAddonPath = '{0}\Windows Kits\10\ADKWinPEAddons' -f $SourcePath;
$ArgumentList1 = '/layout "{0}" /quiet' -f $ADKPath;
$ArgumentList1_1 = '/layout "{0}" /quiet' -f $ADKAddonPath;

# Check if the folder exists, if not, create it
if(Test-Path $SourcePath){
	Write-Host "The folder $SourcePath exists, continuing with install." -ForegroundColor Green
} else {
	Write-Host "The folder $SourcePath does not exist, creating..." -ForegroundColor Yellow -NoNewline
	New-Item $SourcePath -type directory | Out-Null
	Write-Host "done!" -ForegroundColor Green
}
 
# Check if these files exists, if not, download them
$file1 = $SourcePath+"\adksetup.exe"
$file1_1 = $SourcePath+"\adkwinpesetup.exe"
$file2 = $SourcePath+"\MicrosoftDeploymentToolkit_x64.msi"
$file2_1 = $SourcePath+"\MDT_KB4564442.exe"
$file3 = $SourcePath+"\SurfacePro.msi"
$file4 = $SourcePath+"\Surface Ethernet Adapter.zip"
$file5 = $SourcePath+"\Surface Gigabit Ethernet Adapter.zip"


if (Test-Path $file1){
	write-host "The file $file1 exists."
} else {

# Download ADK for Windows 11
	Write-Host "Downloading Adksetup.exe..." -nonewline
	$clnt = New-Object System.Net.WebClient
	$url = "https://go.microsoft.com/fwlink/?linkid=2165884"
	$clnt.DownloadFile($url,$file1)
	Write-Host "done!" -ForegroundColor Green
 }
 
if (Test-Path $ADKPath){
	Write-Host "The folder $ADKPath exists."
} else {
	Write-Host "Downloading and Staging ADK for Windows 11, it is approx 1.5GB in size and will take some time to process, please wait..." -nonewline
	Start-Process -FilePath "$file1" -Wait -ArgumentList $ArgumentList1
	Write-Host "done!" -ForegroundColor Green
} 

if (Test-Path $file1_1){
	write-host "The file $file1_1 exists."
} else {

# Download the ADK for Windows 11 PE add-on
	Write-Host "Downloading Adkwinpesetup.exe..." -nonewline
	$clnt = New-Object System.Net.WebClient
	$url = "https://go.microsoft.com/fwlink/?linkid=2166133"
	$clnt.DownloadFile($url,$file1_1)
	Write-Host "done!" -ForegroundColor Green
 }
 
if (Test-Path $ADKAddonPath){
	Write-Host "The folder $ADKAddonPath exists."
} else {
	Write-Host "Downloading and Staging ADK for Windows 11 PE add-on, it is approximately 3GB in size and will take some time to process, please wait..." -nonewline
	Start-Process -FilePath "$file1_1" -Wait -ArgumentList $ArgumentList1_1
	Write-Host "done!" -ForegroundColor Green
} 

if (Test-Path $file2){
	write-host "The file $file2 exists."
} else {

# Download Microsoft Deployment Toolkit
	Write-Host "Downloading Microsoft Deployment Toolkit..." -nonewline
	$clnt = New-Object System.Net.WebClient
	$url = "https://download.microsoft.com/download/3/3/9/339BE62D-B4B8-4956-B58D-73C4685FC492/MicrosoftDeploymentToolkit_x64.msi"
	$clnt.DownloadFile($url,$file2)
	Write-Host "done!" -ForegroundColor Green
}

if (Test-Path $file2_1){
	write-host "The file $file1_1 exists."
} else {

# Download the Microsoft Deployment Toolkit UEFI Hotfix
	Write-Host "Downloading Adkwinpesetup.exe..." -nonewline
	$clnt = New-Object System.Net.WebClient
	$url = "https://download.microsoft.com/download/3/0/6/306AC1B2-59BE-43B8-8C65-E141EF287A5E/KB4564442/MDT_KB4564442.exe"
	$clnt.DownloadFile($url,$file2_1)
	Write-Host "done!" -ForegroundColor Green
}

if (Test-Path $file3){
	write-host "The file $file3 exists."
} else {

# Download Microsoft Surface Pro drivers
	Write-Host "Downloading Surface Pro drivers..." -nonewline
	$clnt = New-Object System.Net.WebClient
	$url = $DriverReleaseURL
	$clnt.DownloadFile($url,$file3)
	Write-Host "done!" -ForegroundColor Green
}

# extract drivers from the MSI
Write-Host "extracting $file3..." -nonewline
$TargetDir="$SourcePath\Drivers\Microsoft\SurfacePro"
$file_args="/a '$file3' TARGETDIR='$TargetDir' /qn"

start-Process 'MSIEXEC' -ArgumentList "$file_args" -Wait -NoNewWindow
Write-Host "done!" -ForegroundColor Green


if (Test-Path $file4){
	write-host "The file $file4 exists."
} else {
 
# Download Surface Pro Ethernet drivers
	Write-Host "Downloading SurfacePro Ethernet drivers..." -nonewline
	$clnt = New-Object System.Net.WebClient
	$url = "http://download.microsoft.com/download/2/0/7/2073C22F-2F31-4F4A-8059-E54C91C564A9/Surface Ethernet Adapter.zip"
	$clnt.DownloadFile($url,$file4)
	Write-Host "done!" -ForegroundColor Green
}

# unzip the file
Write-Host "unzipping $file4 " -nonewline
$shell_app = new-object -com shell.application
$zip_file = $shell_app.namespace($file4)

if (Test-Path "$SourcePath\Drivers\Microsoft\SurfacePro\Surface100mbEthernetAdapter") {
	$destination = $shell_app.namespace("$SourcePath\Drivers\Microsoft\SurfacePro\Surface100mbEthernetAdapter")
} else {
	mkdir "$SourcePath\Drivers\Microsoft\SurfacePro\Surface100mbEthernetAdapter"
	$destination = $shell_app.namespace("$SourcePath\Drivers\Microsoft\SurfacePro\Surface100mbEthernetAdapter")
}
$destination.Copyhere($zip_file.items(), 0x14)
Write-Host "done!" -ForegroundColor Green
#


if (Test-Path $file5){
	write-host "The file $file5 exists."
} else {
 
# Download SurfacePro Ethernet drivers
	Write-Host "Downloading SurfacePro Gigabit Ethernet drivers..." -nonewline
	$clnt = New-Object System.Net.WebClient
	$url = "https://download.microsoft.com/download/2/0/7/2073C22F-2F31-4F4A-8059-E54C91C564A9/Surface Gigabit Ethernet Adapter.zip"
	$clnt.DownloadFile($url,$file5)
	Write-Host "done!" -ForegroundColor Green
}

# unzip the file
Write-Host "unzipping $file5 " -nonewline
$shell_app = new-object -com shell.application
$zip_file = $shell_app.namespace($file5)

if (Test-Path "$SourcePath\Drivers\Microsoft\SurfacePro\SurfaceGigabitEthernetAdapter") {
	$destination = $shell_app.namespace("$SourcePath\Drivers\Microsoft\SurfacePro\SurfaceGigabitEthernetAdapter")
} else {
	mkdir "$SourcePath\Drivers\Microsoft\SurfacePro\SurfaceGigabitEthernetAdapter"
	$destination = $shell_app.namespace("$SourcePath\Drivers\Microsoft\SurfacePro\SurfaceGigabitEthernetAdapter")
}
$destination.Copyhere($zip_file.items(), 0x14)
Write-Host "done!" -ForegroundColor Green

#
write-host "Downloading and extraction has completed, installing MDT and dependencies now..."

# This installs the Feature .NET Framework (not needed for Server 2016+)
if(([System.Environment]::OSVersion).Version -le 6.3) {
	Write-Host "Installing .NET..." -nonewline
	Import-Module ServerManager
	Add-WindowsFeature as-net-framework
	Write-Host "done!" -ForegroundColor Green
	Start-Sleep -s 10
}

# This installs Windows Deployment Service
Write-Host "Installing Windows Deployment Services..." -nonewline
Import-Module ServerManager
Install-WindowsFeature -Name WDS -IncludeManagementTools
Write-Host "done!" -ForegroundColor Green
Start-Sleep -s 10

# Install ADK Deployment Tools
Write-Host "Installing ADK for Windows 11..." -nonewline
Start-Process -FilePath "$ADKPath\adksetup.exe" -Wait -ArgumentList "/Features OptionId.DeploymentTools OptionId.ImagingAndConfigurationDesigner OptionId.UserStateMigrationTool /norestart /quiet /ceip off"
Write-Host "done!" -ForegroundColor Green
Start-Sleep -s 20

# Install ADK WinPE Addon, Windows Preinstallation Environment
Write-Host "Installing ADK for Windows 11 WinPE Addon..." -nonewline
Start-Process -FilePath "$ADKAddonPath\adkwinpesetup.exe" -Wait -ArgumentList "/Features OptionId.WindowsPreinstallationEnvironment /norestart /quiet /ceip off"
Write-Host "done!" -ForegroundColor Green
Start-Sleep -s 20

# Install Microsoft Deployment Toolkit
Write-Host "Installing Microsoft Deployment Toolkit..." -nonewline
msiexec /qb /i "$file2" | Out-Null
Write-Host "done!" -ForegroundColor Green
Start-Sleep -s 10

# Install Microsoft Deployment Toolkit UEFI Hotfix
Write-Host "Installing Microsoft Deployment Toolkit UEFI Hotfix..." -nonewline
$ArgumentList2_1 = "/extract:`"$($env:ProgramFiles)\Microsoft Deployment Toolkit\Templates\Distribution\Tools`" /quiet";
Start-Process -FilePath "$file2_1" -Wait -ArgumentList $ArgumentList2_1
Write-Host "done!" -ForegroundColor Green
Start-Sleep -s 10

# Initialize and Configure Microsoft Deployment Toolkit
Add-PSSnapIn Microsoft.BDD.PSSnapIn -ErrorAction SilentlyContinue

# Constants
$ShareName = "DeploymentShare$"
$NetPath = "\\$ComputerName\DeploymentShare$"
$MDTDescription = "MDT Deployment Share"

$OStoDeploy = "Windows 11 x64"
$OStoDeployShortName = "Windows 11"
$TSFolder1 = "001"

$TaskSequenceFolderName1 = "Production"
$TaskSequenceFolderName2 = "Test"
$TaskSequenceFolderName3 = "Application Installation Only"

# Make MDT Directory
if (Test-Path "$FolderPath"){
	write-host "'$FolderPath' already exists, will not recreate it."
} else {
	New-Item -ItemType directory -Path "$FolderPath"
}

# Create MDT Shared Folder
New-SmbShare -Name "$ShareName" -Path "$FolderPath"

# Create PS Drive for MDT
new-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root "$FolderPath" -Description "$MDTDescription" -NetworkPath "$NetPath"  -Verbose | add-MDTPersistentDrive -Verbose

# Create OS Folders in MDT GUI
new-item -path "DS001:\Operating Systems" -enable "True" -Name "$OStoDeployShortName" -Comments "" -ItemType "folder" -Verbose
new-item -path "DS001:\Operating Systems\$OStoDeployShortName" -enable "True" -Name "$OStoDeploy" -Comments "" -ItemType "folder" -Verbose

# Create Driver Folders in MDT GUI
new-item -path "DS001:\Out-of-Box Drivers" -enable "True" -Name "WinPE x64" -Comments "" -ItemType "folder" -Verbose
new-item -path "DS001:\Out-of-Box Drivers" -enable "True" -Name $OStoDeployShortName -Comments "" -ItemType "folder" -Verbose
new-item -path "DS001:\Out-of-Box Drivers\$OStoDeployShortName" -enable "True" -Name "Microsoft Corporation" -Comments "" -ItemType "folder" -Verbose
new-item -path "DS001:\Out-of-Box Drivers\$OStoDeployShortName\Microsoft Corporation" -enable "True" -Name "Surface Pro" -Comments "" -ItemType "folder" -Verbose

# Create Packages Folders in MDT GUI
new-item -path "DS001:\Packages" -enable "True" -Name "Language Packs" -Comments "" -ItemType "folder" -Verbose
new-item -path "DS001:\Packages" -enable "True" -Name "MSU" -Comments "" -ItemType "folder" -Verbose

# Create TS Folders in MDT GUI
new-item -path "DS001:\Task Sequences" -enable "True" -Name $TaskSequenceFolderName1 -Comments "" -ItemType "folder" -Verbose
new-item -path "DS001:\Task Sequences" -enable "True" -Name $TaskSequenceFolderName2 -Comments "" -ItemType "folder" -Verbose
new-item -path "DS001:\Task Sequences" -enable "True" -Name $TaskSequenceFolderName3 -Comments "" -ItemType "folder" -Verbose

# Create Application Folders in MDT GUI
new-item -path "DS001:\Applications" -enable "True" -Name "Application Bundles" -Comments "" -ItemType "folder" -Verbose
new-item -path "DS001:\Applications" -enable "True" -Name "Production Applications" -Comments "" -ItemType "folder" -Verbose
new-item -path "DS001:\Applications\Production Applications" -enable "True" -Name "Common" -Comments "" -ItemType "folder" -Verbose
new-item -path "DS001:\Applications\Production Applications" -enable "True" -Name "Dependant" -Comments "" -ItemType "folder" -Verbose
new-item -path "DS001:\Applications" -enable "True" -Name "Test Applications" -Comments "" -ItemType "folder" -Verbose

# Create Selection Profiles in MDT GUI
new-item -path "DS001:\Selection Profiles" -enable "True" -Name "Surface Pro" -Comments "" -Definition "<SelectionProfile><Include path=`"Out-of-Box Drivers\$OStoDeployShortName\Microsoft Corporation\Surface Pro`" /></SelectionProfile>" -ReadOnly "False" -Verbose
new-item -path "DS001:\Selection Profiles" -enable "True" -Name "WinPE x64" -Comments "" -Definition "<SelectionProfile><Include path=`"Out-of-Box Drivers\WinPE x64`" /></SelectionProfile>" -ReadOnly "False" -Verbose

# Import MDT PowerShell Commands
Import-Module "C:\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"

# Import Operating System Source Files
#import-mdtoperatingsystem -path "DS001:\Operating Systems\$OStoDeployShortName\$OStoDeploy" -SourcePath "$SourcePath\Operating Systems\$OStoDeploy" -DestinationFolder "$OStoDeployShortName\$OStoDeploy" -Verbose

# Import MSU
#import-mdtpackage -path "DS001:\Packages\MSU" -SourcePath "$SourcePath\MSU" -Verbose

# Import Applications
#import-MDTApplication -path "DS001:\Applications\Core Applications" -enable "True" -Name "Microsoft Office 365 Pro Plus x86" -ShortName "Office 365 Pro Plus" -Version "x86" -Publisher "" -Language "" -CommandLine "Setup.EXE /configure Install_Production.xml" -WorkingDirectory ".\Applications\Office 365 Pro Plus x86" -ApplicationSourcePath "$SourcePath\Applications\Core Applications\Microsoft Office 365 Pro Plus x86" -DestinationFolder "Office 365 Pro Plus x86" -Verbose

# Import Drivers
import-mdtdriver -path "DS001:\Out-of-Box Drivers\$OStoDeployShortName\Microsoft Corporation\Surface Pro" -sourcePath "$SourcePath\Drivers\Microsoft\SurfacePro" -Verbose

#import Network drivers into WinPE x64
import-mdtdriver -path "DS001:\Out-of-Box Drivers\WinPE x64" -SourcePath "$SourcePath\Drivers\Microsoft\SurfacePro\SurfaceGigabitEthernetAdapter" -Verbose
import-mdtdriver -path "DS001:\Out-of-Box Drivers\WinPE x64" -SourcePath "$SourcePath\Drivers\Microsoft\SurfacePro\Surface100mbEthernetAdapter" -Verbose

# This will update the file DeployWiz_ComputerName.vbs
# to support domain OU friendly names.
$DomainOUListFile = @"
<?xml version="1.0" encoding="utf-8"?>
<DomainOUs>
	<DomainOU value="$Default_Computers_OU">
		Default Computers OU
	</DomainOU>
</DomainOUs>
"@
New-Item -Path "$FolderPath\Control\DomainOUList.xml" -ItemType File -Value $DomainOUListFile
$DWCNFile = "$FolderPath\Scripts\DeployWiz_ComputerName.vbs"
(Get-Content $DWCNFile) | Foreach-Object {
    $_ -replace 'Function AddItemToMachineObjectOUOpt\(item\)', 'Function AddItemToMachineObjectOUOpt(item,value)' `
       -replace 'oOption.Value = item', 'oOption.Value = value' `
       -replace 'AddItemToMachineObjectOUOpt oItem.text', 'AddItemToMachineObjectOUOpt oItem.text, oItem.Attributes.getNamedItem("value").value'
    } | Set-Content $DWCNFile
Write-Host "Computer OU friendly names have been enabled." -ForegroundColor Green


##############################################
# Uses the "Clients.xml" file to create a new template and creates
# a "Win10_Clients.xml" and "Win11_Clients.xml" file in the "Templates" folder when completed.
#
# The new template is designed for Windows 10 and has a few changes.
#  1) Adds a custom step for a drivers path variable "DriverGroup001".
#  2) Changes the "DriverSectionProfile" from "All Drivers" to "Nothing".
#  3) Changes the name and title of the template.
#
#Win10_Clients XML File
$ts_step = [xml]@"
    <step type="SMS_TaskSequence_SetVariableAction" name="Set Drivers Path" description="" disable="false" continueOnError="false" successCodeList="0 3010">
      <defaultVarList>
        <variable name="VariableName" property="VariableName">DriverGroup001</variable>
        <variable name="VariableValue" property="VariableValue">Windows 10\%Make%\%Model%</variable>
      </defaultVarList>
      <action>cscript.exe "%SCRIPTROOT%\ZTISetVariable.wsf"</action>
    </step>
"@
$ts_tmpl               = "$env:programfiles\Microsoft Deployment Toolkit\Templates\"
$ts_ref                = "$($ts_tmpl)Client.xml"
$tsXML                 = [xml](Get-Content $ts_ref)
$new_node              = $tsXML.ImportNode($ts_step.get_DocumentElement(), $true)
$task_node             = $tsXML.SelectSingleNode('//sequence/group/step[@type="BDD_InjectDrivers" and @name="Inject Drivers"]')
$task_inner            = $task_node.defaultVarList.variable | Where-Object {($_.Name -like "DriverSelectionProfile") -and ($_.Property -like "DriverSelectionProfile") -and ($_.'#text' -like "All Drivers")}
$task_parent           = $task_node.ParentNode
$task_inner.'#text'    = "Nothing"
$ts_header             = $tsXML.sequence | Where-Object {($_.Name -like "Standard Client Task Sequence") -and ($_.Description -like "A complete task sequence for deploying a client operating system")}
$ts_header.name        = "Windows 10 Client Task Sequence"
$ts_header.description = "A complete task sequence for deploying a Windows 10 client operating system with model specific driver support"
$task_parent.InsertBefore($new_node,$task_node)
$tsXML.Save("$($ts_tmpl)Win10_Client.xml")

#Win11_Clients XML File
$ts_step = [xml]@"
    <step type="SMS_TaskSequence_SetVariableAction" name="Set Drivers Path" description="" disable="false" continueOnError="false" successCodeList="0 3010">
      <defaultVarList>
        <variable name="VariableName" property="VariableName">DriverGroup001</variable>
        <variable name="VariableValue" property="VariableValue">Windows 11\%Make%\%Model%</variable>
      </defaultVarList>
      <action>cscript.exe "%SCRIPTROOT%\ZTISetVariable.wsf"</action>
    </step>
"@
$ts_tmpl               = "$env:programfiles\Microsoft Deployment Toolkit\Templates\"
$ts_ref                = "$($ts_tmpl)Client.xml"
$tsXML                 = [xml](Get-Content $ts_ref)
$new_node              = $tsXML.ImportNode($ts_step.get_DocumentElement(), $true)
$task_node             = $tsXML.SelectSingleNode('//sequence/group/step[@type="BDD_InjectDrivers" and @name="Inject Drivers"]')
$task_inner            = $task_node.defaultVarList.variable | Where-Object {($_.Name -like "DriverSelectionProfile") -and ($_.Property -like "DriverSelectionProfile") -and ($_.'#text' -like "All Drivers")}
$task_parent           = $task_node.ParentNode
$task_inner.'#text'    = "Nothing"
$ts_header             = $tsXML.sequence | Where-Object {($_.Name -like "Standard Client Task Sequence") -and ($_.Description -like "A complete task sequence for deploying a client operating system")}
$ts_header.name        = "Windows 11 Client Task Sequence"
$ts_header.description = "A complete task sequence for deploying a Windows 11 client operating system with model specific driver support"
$task_parent.InsertBefore($new_node,$task_node)
$tsXML.Save("$($ts_tmpl)Win11_Client.xml")

# Create Task Sequence
#import-mdttasksequence -path "DS001:\Task Sequences\$TaskSequenceFolderName1" -Name "My First Task Sequence - $OStoDeploy" -Template "Win11_Client.xml" -Comments "" -ID "$TSFolder1" -Version "1.0" -OperatingSystemPath "DS001:\Operating Systems\$OStoDeployShortName\$OStoDeploy\Windows 11 Pro in $OStoDeploy install.wim" -FullName "Windows User" -OrgName "$CompanyName" -HomePage "www.google.ca" -AdminPassword "$Wks_AdminPwd" -Verbose

#############################################
# This will replace the standard customsettings.ini with the below
# edit variables with your own values
#

$CSFile = @"
[Settings]
Priority=TaskSequenceID, Model, Default
Properties=MyCustomProperty, NeedRebootTpmClear, MaskedVariables

[Default]
_SMSTSOrgName=$CompanyName
MaskedVariables=_SMSTSReserved2,OSDUserStateKeyPassword

ScanStateArgs=/v:5 /o /c
LoadStateArgs=/v:5 /c /lac /lae

OSInstall=Y

SkipRoles=YES
SkipCapture=YES
SkipTimeZone=YES
SkipUserData=YES
SkipBitLocker=YES
SkipProductKey=YES
SkipAdminPassword=YES
#SkipAppsOnUpgrade=YES
SkipComputerBackup=YES
SkipDeploymentType=YES
SkipLocaleSelection=YES

#BDEInstallSuppress=NO
#BDEWaitForEncryption=FALSE
#BDEDriveLetter=S:
#BDEDriveSize=2000
#BDEInstall=TPM
#BDEKeyLocation=C:\Windows\Temp
#BDERecoveryKey=AD

JoinDomain=$Domain_FQ
DomainAdmin=$MDT_Admin
DomainAdminDomain=$Domain_FQ
DomainAdminPassword=$MDT_AdminPwd
MachineObjectOU=$Default_Computers_OU

UILanguage=en-US
UserLocale=en-CA
KeyboardLocale=en-US
TimeZoneName=Mountain Standard Time

#WsusServer=http://$WSUS_SVR.$Domain_FQ:8530

#WUMU_ExcludeKB001=982861
#WUMU_ExcludeKB002=976002
#WUMU_ExcludeKB003=2267621
#WUMU_ExcludeKB004=2434419

[SurfacePro]
XResolution=2736
YResolution=1824
"@ 

Remove-Item -Path "$FolderPath\Control\CustomSettings.ini" -Force
New-Item -Path "$FolderPath\Control\CustomSettings.ini" -ItemType File -Value $CSFile


#############################################
# This will replace the standard bootstrap.ini with the below
#
$BSFile = @"
[Settings]
Priority=Default

[Default]
_SMSTSOrgName=$CompanyName

BitsPerPel=32
VRefresh=60
XResolution=1
YResolution=1

#UserID=$MDT_Admin
#UserPassword=$MDT_AdminPwd
UserDomain=$Domain_NB
DeployRoot=$NetPath
"@ 

Remove-Item -Path "$FolderPath\Control\BootStrap.ini" -Force
New-Item -Path "$FolderPath\Control\BootStrap.ini" -ItemType File -Value $BSFile

<#
##############################################
# Make modifications to the Task Sequence
$TSXMLFile = "$FolderPath\Control\$TSFolder1\ts.xml"
# load the task sequence XML file
[xml]$TSSettingsXML = Get-Content $TSXMLFile
# replace select profile with Surface Pro
$TSSettingsXML.Sequence.Group.Step | Where-Object {$_.Name -like "*Inject Driver*"} | ForEach-Object {
    $CurrentObject = $_
    if ($CurrentObject.RunIn -like "WinPEandFullOS") {
        $CurrentObject.defaultVarList.variable | Where-Object { $_.Name -like "DriverSelectionProfile" } | ForEach-Object {
            $_."#text" = "Surface Pro"
        }
        }
# replace Auto with all for drivers to use from the selected profile
    if ($CurrentObject.RunIn -like "WinPEandFullOS") {
       $CurrentObject.defaultVarList.variable | Where-Object { $_.Name -like "DriverInjectionMode" } | ForEach-Object {
            $_."#text" = "ALL"
        }
    }
}
$TSSettingsXML.Save($TSXMLFile)


# add the Surface Pro WMI query
$TSXMLFile = "$FolderPath\Control\$TSFolder1\ts.xml"
[xml]$TSSettingsXML = Get-Content $TSXMLFile
$InjectDriversElement = $TSSettingsXML.Sequence.Group.Step | Where-Object {($_.Name -like "*Inject Driver*") -and ($_.runIn -like "WinPEandFullOS")}
$ConditionElement = $InjectDriversElement.AppendChild($TSSettingsXML.CreateElement("condition"))
$ExpressionElement = $ConditionElement.AppendChild($TSSettingsXML.CreateElement("expression"))
$ExpressionElement.SetAttribute("type", "SMS_TaskSequence_WMIConditionExpression")
$VariableNameElement = $ExpressionElement.AppendChild($TSSettingsXML.CreateElement("variable"))
$VariableNameElement.SetAttribute("name", "Namespace")
$VariableNameTextNode = $VariableNameElement.AppendChild($TSSettingsXML.CreateTextNode("root\cimv2"))
$VariableQueryElement = $ExpressionElement.AppendChild($TSSettingsXML.CreateElement("variable"))
$VariableQueryElement.SetAttribute("name", "Query")
$VariableQueryTextNode = $VariableQueryElement.AppendChild($TSSettingsXML.CreateTextNode('SELECT * FROM Win32_ComputerSystem WHERE Model Like "%Surface Pro"'))
$TSSettingsXML.Save($TSXMLFile)
#>

# Modify MDT Directory and Shared Folder Permissions
#
# Base Folder Permissions
Write-Host "Configuring base NTFS Permissions for the MDT deployment folder..." -nonewline
icacls $FolderPath /grant '"Users":(OI)(CI)(RX)'
icacls $FolderPath /grant '"Administrators":(OI)(CI)(F)'
icacls $FolderPath /grant '"SYSTEM":(OI)(CI)(F)'
Write-Host "done!" -ForegroundColor Green

# Base Share Permissions
Write-Host "Configuring base Sharing Permissions for the MDT deployment share..." -nonewline
Grant-SmbShareAccess -Name $ShareName -AccountName "Administrators" -AccessRight Full -Force
Grant-SmbShareAccess -Name $ShareName -AccountName "EVERYONE" -AccessRight Read -Force
Revoke-SmbShareAccess -Name $ShareName -AccountName "CREATOR OWNER" -Force
Write-Host "done!" -ForegroundColor Green

# MDT Admin Specific Permissions
if ($MDT_Admin_is_Domain_Admin -ne "false"){
	Write-Host "User account permissions for MDT Admin user $MDT_Admin to $FolderPath not required." -ForegroundColor Green
} elseif ($MDT_Admin_is_Domain_Admin -eq "false"){
	$searcher = [adsisearcher]"(samaccountname=$MDT_Admin)"
	$rtn = $searcher.findall()
	if ($rtn.count -gt 0) {
		Write-Host "Configuring MDT Admin specific NTFS Permissions for the MDT deployment folder..." -nonewline
		icacls $FolderPath /grant ""$Domain_NB\$MDT_Admin":(OI)(CI)(M)"
		icacls "$FolderPath\Captures" /grant ""$Domain_NB\$MDT_Admin":(OI)(CI)(M)"
		Write-Host "done!" -ForegroundColor Green
	} else {
		Write-Host "Warning!: " -nonewline -ForegroundColor Yellow
		Write-Host "MDT Admin user account not found, did not add permissions for $MDT_Admin to $FolderPath" -ForegroundColor Red
	}
}



# Initialize and start the WDS server
wdsutil /Verbose /Progress /Initialize-Server /RemInst:$WDSPath
Start-Sleep -s 10
Write-Host "Attempting to start WDS..." -NoNewline
wdsutil /Verbose /Start-Server
Start-Sleep -s 10

# This sets WDS to reply to all computers that PXE boot
Write-Host "setting PXE response policy..." -NoNewline
wdsutil /Set-Server /AnswerClients:All
Start-Sleep -s 10

# This sets WDS to disable Variable Window Extension
Write-Host "setting Variable Window Extension..." -NoNewline
wdsutil /Set-TransportServer /EnableTftpVariableWindowExtension:No
Start-Sleep -s 10


##############################################
# Disable the X86 boot wim and change the Selection Profile for
# the X64 boot wim to use the ADK WIM instead of the OS WIM.
#
$XMLFile = "$FolderPath\Control\Settings.xml"
[xml]$SettingsXML = Get-Content $XMLFile
$SettingsXML.Settings."EnableMulticast" = "False"
$SettingsXML.Settings."SupportX86" = "False"
$SettingsXML.Settings."Boot.x64.SelectionProfile" = "WinPE x64"
$SettingsXML.Settings."Boot.x86.UseBootWim" = "False"
$SettingsXML.Settings."Boot.x64.UseBootWim" = "False"
$SettingsXML.Save($XMLFile)

#Update the Deployment Share to create the boot wims and iso files
update-MDTDeploymentShare -path "DS001:" -Force -Verbose
Start-Sleep -s 60

# Import boot image into WDS
Write-Host "Importing Boot image..." -NoNewline 
Import-WdsBootImage -Path $FolderPath\Boot\LiteTouchPE_x64.wim -NewImageName "Lite Touch Windows PE (x64)" –SkipVerify

# All done
Write-Host "TO-DO: " -NoNewLine -ForegroundColor Yellow
Write-Host "Edit the file $FolderPath\Scripts\DomainOUList.xml to reflect the current computer OU structure." -ForegroundColor White
Write-Host "`nInstallation and configuration has completed. If you encountered any WDS errors, please restart the server and verify that the WDS service is started." -ForegroundColor Green
