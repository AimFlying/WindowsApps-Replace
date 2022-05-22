$WinAppsPaths = @("C:\Program Files\WindowsApps")

Write-Host
Write-Host "Welcome on WAR - WindowsApps Replace" -ForegroundColor Green

$WinVer = [Environment]::OSVersion.Version

if (-not ($WinVer.Major -eq 10 -and $WinVer.Build -lt 22000))
{
	Write-Host
	Write-Warning "This script was only tested on Windows 10 and 11." -WarningAction Inquire
}

if ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne 'S-1-5-18')
{
	Write-Host
	Write-Host "Please starting the script via PSExec." -ForegroundColor Red
	Write-Host
	pause
	exit 1
}

$WinAppsPaths = $WinAppsPaths | ForEach-Object { [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') }

foreach ($WinAppsPath in $WinAppsPaths)
{
	if (-not ((Test-Path $WinAppsPath -PathType Container) -and $((Get-Item $WinAppsPath -Force).Name -eq 'WindowsApps')))
	{
		Write-Host
		Write-Host 'The WindowsApps folder does not exist.' -ForegroundColor Red
		Write-Host
		pause
		exit 1
	}
}

[Regex]$FirstParenthesis = '\('

foreach ($WinAppsPath in $WinAppsPaths)
{
	Write-Host
	Write-Host "Fixing WindowsApps folder permissions" -ForegroundColor Cyan

	$WinAppsDefaultPerms = 'O:S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464G:SYD:PAI(A;;FA;;;S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464)(A;OICIIO;GA;;;S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464)(A;;0x1200a9;;;S-1-15-3-1024-3635283841-2530182609-996808640-1887759898-3848208603-3313616867-983405619-2501854204)(A;OICIIO;GXGR;;;S-1-15-3-1024-3635283841-2530182609-996808640-1887759898-3848208603-3313616867-983405619-2501854204)(A;;FA;;;SY)(A;OICIIO;GA;;;SY)(A;CI;0x1200a9;;;BA)(A;OICI;0x1200a9;;;LS)(A;OICI;0x1200a9;;;NS)(A;OICI;0x1200a9;;;RC)(XA;;0x1200a9;;;BU;(Exists WIN://SYSAPPID))'

	$WinAppsACL = Get-Acl $WinAppsPath
	$WinAppsACL.SetSecurityDescriptorSddlForm($WinAppsDefaultPerms)

	$GroupID = New-Object Security.Principal.SecurityIdentifier('S-1-15-2-1')
	$NewRule = New-Object Security.AccessControl.FileSystemAccessRule($GroupID, 'ReadAndExecute', 'ObjectInherit,ContainerInherit', 'None', 'Allow')
	$WinAppsACL.AddAccessRule($NewRule)

	$GroupID = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-545')
	$NewRule = New-Object Security.AccessControl.FileSystemAccessRule($GroupID, 'ReadAndExecute', 'ObjectInherit,ContainerInherit', 'InheritOnly', 'Allow')
	$WinAppsACL.AddAccessRule($NewRule)

	$GroupID = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
	$NewRule = New-Object Security.AccessControl.FileSystemAccessRule($GroupID, 'FullControl', 'ObjectInherit,ContainerInherit', 'None', 'Allow')
	$WinAppsACL.AddAccessRule($NewRule)

	Set-Acl $WinAppsPath $WinAppsACL

	$DeepFixInheritance = 0

	if (-not $DeepFixInheritance)
	{
		$AppxFolders = Get-ChildItem $WinAppsPath -Filter 'AppxMetadata' -Depth 1 -Directory -Force -Attributes !ReparsePoint  # ignores junctions

		if (($AppxFolders | Where-Object { (Get-Acl $_.FullName).AreAccessRulesProtected }).Count -gt 0)
		{
			$DeepFixInheritance = 1
		}
	}

	Write-Host

	if ($DeepFixInheritance)
	{
		Write-Host "Fixing WindowsApps folder tree inheritance..." -ForegroundColor Cyan
		icacls "$WinAppsPath\*" /inheritance:e /t /c /q 2>$null
	}
	else
	{
		Write-Host "Fixing WindowsApps subfolders inheritance..." -ForegroundColor Cyan
		icacls "$WinAppsPath\*" /inheritance:e /c /q 2>$null
	}

	Write-Host
	Write-Host "Fixing WindowsApps subfolders permissions..." -ForegroundColor Cyan

	$AppsFolders = Get-ChildItem $WinAppsPath -Exclude *_* -Directory -Force -Attributes !ReparsePoint
	$AppsFolders = @($WinAppsPath) + ($AppsFolders | ForEach-Object { $_.FullName })

	foreach ($AppsFolder in $AppsFolders)
	{
		$AppFolders = Get-ChildItem $AppsFolder -Directory -Force -Attributes !ReparsePoint

		foreach ($AppFolder in $AppFolders)
		{
			if ($AppFolder.Name -Match '(.+?_).*?_.*?_.*?_(\w+$|\w{1,13})')
			{
				$AppFolderPath = $AppFolder.FullName
				$AppFolderACL = Get-Acl $AppFolderPath

				$MsBullshit = '(XA;OICI;0x1200a9;;;BU;(WIN://SYSAPPID Contains "{0}{1}"))' -f $Matches.1, $Matches.2

				if ($AppFolderACL.Sddl -NotMatch ([Regex]::Escape($MsBullshit)))
				{
					Write-Host "Fixing $AppFolderPath"
					$AppFolderSDDL = $FirstParenthesis.Replace($AppFolderACL.Sddl, "$MsBullshit(", 1)
					$AppFolderACL.SetSecurityDescriptorSddlForm($AppFolderSDDL)
					Set-Acl $AppFolderPath $AppFolderACL
				}
			}
		}
	}

	$WpSystem = Join-Path $WinAppsPath "..\WpSystem"

	if (Test-Path $WpSystem -PathType Container)
	{
		Write-Host
		Write-Host "Fixing WpSystem permissions..." -ForegroundColor Cyan

		icacls $WpSystem /grant "*S-1-15-2-1:(OI)(CI)(IO)(F)" /q

		icacls $WpSystem /grant "*S-1-5-32-545:(RX)" /q

		icacls $WpSystem /grant "*S-1-5-32-544:(OI)(CI)(F)" /q
	}
}

$Username = (Get-WMIObject Win32_ComputerSystem).UserName.Split('\')[-1]
$AppDataPackages = "C:\Users\$Username\AppData\Local\Packages"

Write-Host

if (Test-Path $AppDataPackages -PathType Container)
{
	Write-Host "Fixing AppData Packages permissions..." -ForegroundColor Cyan

	icacls $AppDataPackages /inheritance:e /t /c /q

	icacls $AppDataPackages /grant "*S-1-15-2-1:(OI)(CI)(F)"
}
else
{
	Write-Warning "AppData Packages not found, please file a GitHub issue here:
https://github.com/AgentRev/WindowsAppsUnfukker/issues
Copy-paste this in the description: $AppDataPackages"
}

Write-Host
Write-Host "WindowsApps folder was replaced ! Don't forget to star the project on https://github.com/AimFlying/WindowsApps-Replace/ if it's worked."  -ForegroundColor Green
Write-Host
pause
