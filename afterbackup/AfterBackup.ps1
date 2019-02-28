#
# AfterBackup.ps1
#
# This script is delivered as an example of how you would automate additional SCCM backup tasks.  Use this script at your own risk
function Backup-SCCM
{

	$script:sb.Append("Called Backup-SCCM`r`n")
	
	$script:sb.Append("Number of backups to keep is set to " + $script:NumberOfBckUpsToKeep + " `r`n")
	#test parameters
    if($script:NumberOfBckUpsToKeep -ile 0)
    {
		#default to 5
		$script:sb.Append("Defaulting to keeping 5 backups`r`n")
		$script:NumberOfBckUpsToKeep = 5
    }

	#Manage Backup Directories
	$numOfDirs = (Get-ChildItem -Path $script:BackupFolderPath -Directory).Count
	$script:sb.Append("Number of directories currently in the backup location is " + $numOfDirs.ToString() + " `r`n")
	if($numOfDirs -ige $script:NumberOfBckUpsToKeep)
	{
		$script:sb.Append("Deleting oldest folder in backup location `r`n")
		#delete oldest
		Delete-OldestFolder

	}

	# create folder
	$script:sb.Append("Calling Create-BackupFolder `r`n")
	Create-BackupFolder -FolderPath $BackupFolderPath
	Write-Log -Line $script:sb.ToString() -LogFilePath $script:LogFilePath	

	 # create backup
	$script:sb.Append("Calling Write-Backup`r`n")
	Write-Backup
	Write-Log -Line $script:sb.ToString() -LogFilePath $script:LogFilePath
}

function Create-BackupFolder
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$FolderPath
    )
	$tempPath = ""
	$script:sb.Append("Create-BackupFolder called `r`n")
    try
    {
        if(!($FolderPath.EndsWith("\")))
        {
			$script:sb.Append("Adding a trailing backslash to the folder path `r`n")
            $FolderPath += "\"
			$script:sb.Append("New Folder Path = " + $FolderPath + " `r`n")
        }
        $dateName = Get-Date -Format FileDate
		$tempPath = $FolderPath + $dateName
		$script:sb.Append("Adding new folder to contain backup data  to the backup path`r`n")
		$script:sb.Append("Folder path to backup data for this session = " + $tempPath + " `r`n")
        if(Test-Path $tempPath)
        {
			$script:sb.Append("Folder " + $dateName + "already exists `r`n")
            #delete oldest or deleted this one so we can overwrite it?
            if(!Test-Path ($tempPath + "OLD"))
            {
				$script:sb.Append("Renaming Folder " + $dateName + " to " + ($dateName + "OLD") + "`r`n")
                Rename-Item -Path ($FolderPath + $dateName) -NewName "Old" -Force
				$script:sb.Append("Creating new folder `r`n")
                New-Item -Path ($FolderPath) -Name $dateName -ItemType "Directory" 
            }
			else
			{
				$script:sb.Append("Folder " + ($tempPath + "OLD") + "already exists `r`n")
				#if we just continue, all contents will be updated in the new folder
			}
            #Get-ChildItem ($FolderPath + $FolderName + $dateName) -Recurse |  Remove-Item -Force 
        }
        else
        {
            #Folder doesn't exist
		   $script:sb.Append("Creating new folder named " + $dateName + " `r`n")
           $temp = New-Item -Path ($FolderPath) -Name $dateName -ItemType "Directory"    
        }
    }
    catch
    {
    }
	$script:sb.Append("Returning path to new folder `r`n")
	$script:sb.Append("New path = " + $tempPath + " `r`n")
    $script:newBackupPath = $tempPath
	Write-Log -Line $script:sb.ToString() -LogFilePath $script:LogFilePath
	return $script:newBackupPath
}

function Backup-Databases
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$ServerInstance,
        [Parameter(Mandatory=$false)]
        [string]$BackupPath,
        [Parameter(Mandatory=$false)]
        [string[]]$DatabaseNames
    )
    #check parameter data
	$script:sb.Append("Backup-Databases called `r`n")
	$script:sb.Append("Databases to backup.. `r`n")
	foreach($db in $DatabaseNames)
	{
		$script:sb.Append($db + " `r`n")
	}

    if(-Not $BackupPath.EndsWith("\"))
    {
        $BackupPath += "\"
    }
	$script:sb.Append("Backup databases to path: " + $BackupPath + " `r`n")
    foreach($dbName in $DatabaseNames)
    {
        $fileName = $dbname + ".bak"
		$script:sb.Append("Backing up database: " + $dbName + " `r`n")
		$script:sb.Append((Get-Date).ToString() + " Start Backing up " + $dbName + " `r`n")
        $temp = Backup-SqlDatabase -ServerInstance $ServerInstance -Database $dbName -BackupFile ($BackupPath + $dbName + ".bak")
		$script:sb.Append((Get-Date).ToString() + " Backup of " + $dbName + " successful `r`n")
    }     
    
}

function Backup-FolderAndContents
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false)]
        [string]$FolderSource,
        [Parameter(Mandatory=$false)]
        [string]$FolderDestination,
        [Parameter(Mandatory=$false)]
        [string]$FolderName
    )
	 $script:sb.Append("Calling Backup-FolderAndContents `r`n")
	 $script:sb.Append("Source Folder = " + $FolderSource + "`r`n")
	$script:sb.Append("Destination Folder = " + $FolderDestination + "`r`n")
	$script:sb.Append("Child Folder Name = " + $FolderName + "`r`n")
	$script:sb.Append("Checking if Source and Destination folders exist `r`n")
    if((Test-Path -Path $FolderSource) -and (Test-Path -Path $FolderDestination))
    {
		$script:sb.Append("Both locations exist `r`n")
		$script:sb.Append("Are we creating a child folder for this content? `r`n")
        if($FolderName.Equals(""))
        {
			$script:sb.Append("No child folder created `r`n")
			$script:sb.Append("Copying starting: " + (Get-Date).ToString() + " `r`n")
            Copy-Item -Path $FolderSource -Destination $FolderDestination -Recurse -Force
			$script:sb.Append("Copying ending: " + (Get-Date).ToString() + " `r`n")
        }
        else
        {
			$script:sb.Append("Creating child folder named " + $FolderName + " `r`n")
			if(-not $FolderDestination.EndsWith("\"))
			{
				$FolderDestination = $FolderDestination + "\"
			}
			$FolderDestination += $FolderName
			$script:sb.Append("New destination folder name and path =  " + $FolderDestination + " `r`n")
			$script:sb.Append("Copying starting: " + (Get-Date).ToString() + " `r`n")
            Copy-Item -Path $FolderSource -Destination $FolderDestination -Recurse -Force
			$script:sb.Append("Copy Ending: " + (Get-Date).ToString() + " `r`n")
			$script:sb.Append("Copying completed successfully `r`n")
        }
    }
    else
    {
        #bad
        #Copy-Item -Path $ContentLibraryLocationSource -Destination $ContentLibraryLocationDestination -Recurse
    }
}

function Get-OldestFolder
{
    [CmdletBinding()]
    Param(
       [Parameter(Mandatory=$False)]
       [string]$FolderPath
    )
	$directoryName = ""
	$directories = Get-ChildItem -Path $script:BackupFolderPath -Directory
	[DateTime] $Earliest = "1 January 2199"
	foreach($dir in $directories)
	{
		$currentDT = $dir.CreationTime
		if($currentDT.CompareTo($Earliest) -ilt 0)
		{
			$directoryName = $dir.Name
			$Earliest = $currentDT
		}
	}
	return $directoryName
}

function Delete-OldestFolder
{
	$script:sb.Append("Delete-OldestFolder called `r`n")
	try
	{
		$script:sb.Append("Getting oldest folder `r`n")
		$OldFolder = Get-OldestFolder -FolderPath $script:BackupFolderPath
		$script:sb.Append("Oldest folder detected as " + $OldFolder + " `r`n")
		$FullPath = ($script:BackupFolderPath + "\" + $OldFolder)
		$script:sb.Append("Removing old folder `r`n")
		$script:sb.Append("Removal path = " + $FullPath + " `r`n")
		Remove-Item -Path $FullPath -Recurse -Force
		$script:sb.Append("Removal completed `r`n")
	}
	catch
	{
		$script:sb.Append("Error in Delete-OldestFolder, removal failed `r`n")
		if($_.Exception.Message -ine $null)
		{
			$script:sb.Append("Error message: " + $_.Exception.Message + "  `r`n")
		}
	}
}

#deprecated
function Rename-OldestFolder
{
    [CmdletBinding()]
    Param(
       [Parameter(Mandatory=$False)]
       [string]$BackupFolderSource
		)
		$OldFolder = Get-OldestFolder -FolderPath $BackupFolderPath
		Rename-Item -Path $OldFolder -NewName ($OldFolder + "Old")
    

	$OldFolder = Get-OldestFolder -FolderPath $BackupFolderPath

	Rename-Item -Path $OldFolder -NewName ($OldFolder + "Old")
}

function Write-Backup
{

	#SQL databases
	if($script:BackupSQL)
	{
		$script:sb.Append("Backing up SQL Databases `r`n")
		Backup-Databases -ServerInstance $SQLServer -BackupPath $script:newBackupPath -DatabaseNames $databaseList
		Write-Log -Line $script:sb.ToString() -LogFilePath $script:LogFilePath
	}

	#ContentLibrary
	if($script:BackupContentLibrary)
	{
		$script:sb.Append("Backing up Content Library `r`n")
		Backup-FolderAndContents -FolderSource $ContentLibraryLocation -FolderDestination $script:newBackupPath
		Write-Log -Line $script:sb.ToString() -LogFilePath $script:LogFilePath
	}

	#SCCM backup blob
	if($script:BackupSCCMBlob)
	{
		$script:sb.Append("Backing up SCCM Blob `r`n")
		Backup-FolderAndContents -FolderSource $SCCMBackupLocation -FolderDestination $script:newBackupPath
		Write-Log -Line $script:sb.ToString() -LogFilePath $script:LogFilePath
	}

	#WSUS
	if($script:BackupWSUS)
	{
		$script:sb.Append("Backing up WSUS `r`n")
		Backup-FolderAndContents -FolderSource $WSUSContentLocation -FolderDestination $script:newBackupPath -FolderName $WsusFolderName
		Write-Log -Line $script:sb.ToString() -LogFilePath $script:LogFilePath
	}

}

function Write-Log 
{
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory=$False)]
    [string]$Line,
    [Parameter(Mandatory=$False)]
    [string]$LogFilePath
  )
	try
	{
		if($Line.Equals("") -or $script:LogFilePath.Equals(""))
		{
			return
		}
		if(-Not (Test-Path -Path $script:LogFilePath))
		{
			# create file?
		}
		[string] $data = (Get-Date).ToString() + " - "
		$data += $Line
		$data += "`r`n"

		#$LogFile += "$($env:COMPUTERNAME)-AfterBackupLogFile.txt"
		$data | Out-File -FilePath $script:LogFilePath -Append
	}
	catch
	{}
  $script:sb.Clear()
}


##################################### Start Code ##########################################################################
Import-Module -Name SQLServer

# **************** Toggle Features ************************
$testing = $true
$script:BackupWSUS = $true
$script:BackupSQL = $true
$script:BackupContentLibrary = $false
$script:BackupSCCMBlob = $false

# **************** Script Variables ************************

# Number of backups to keep
$script:NumberOfBckUpsToKeep = 7

#SQL Server
$databaseList = "CM_M24", "ReportServer", "ReportServerTempDB", "SUSDB"
$SQLServer = "SCCM-CB"

#SCCM Blob backup
$SCCMBackupLocation = ""

#Content Library
$ContentLibraryLocation = "\\SCCM-CB\C$\SCCMContentLib"

#WSUS
$WSUSContentLocation = "\\SCCM-CB\Source\WSUS"
$WsusFolderName = "WSUS"

#Location to backup data
$script:BackupFolderPath = "\\sccm-cb\source\Backups\PowerShell\Retention"

#Script log file
$script:LogFilePath = "\\sccm-cb\source\backups\PowerShell\Retention\AfterBackupPS1.log"

#String builder for logging
$script:sb = New-Object -TypeName "System.Text.StringBuilder"

#backup path after scripts creates the backup folder.  That NEW path is assigned to this variable
$script:newBackupPath = ""

# **************** Write variable values to log ************************
$script:sb.Append("Start AfterBackup.PS1************************************************** `r`n")
$script:sb.Append("Variable values`r`n")
$script:sb.Append("`tSQL Server: " + $SQLServer + "`r`n")
$script:sb.Append("`tContent Library Path: " + $ContentLibraryLocation + "`r`n")
$script:sb.Append("`tWSUS Content Path: " + $WSUSContentLocation + "`r`n")
$script:sb.Append("`tWSUS Folder Name: " + $WsusFolderName + "`r`n")
$script:sb.Append("`tSCCM Backup Path: " + $SCCMBackupLocation + "`r`n")
$script:sb.Append("`tBackup Folder Path: " + $BackupFolderPath + "`r`n")
$script:sb.Append("`tLog file path: " + $script:LogFilePath + "`r`n")
$script:sb.Append("Start Processing`r`n")

# **************** Start Processing ************************
Write-Log -Line $script:sb.ToString() -LogFilePath $script:LogFilePath
Backup-SCCM
$script:sb.Append("End AfterBackup.PS1***************************************************** `r`n")
$script:sb.Append("`r`n")
Write-Log -Line $script:sb.ToString() -LogFilePath $script:LogFilePath