<#
    .SYNOPSIS
        Script for automating Minecraft Bedrock Server Updating
    .DESCRIPTION
        Script which will automatically retrieve the newest version of Bedrock Minecraft.
        Then download it and install the newest version. The script will also send out
        an email notification that the server has been updated.

    .NOTES
        You will need to input the following information for the variables
        in the EMAIL SECTION at the end of the script.

        $From,
        $Password,
        $To,
        $SMTPServer
#>

param(
    [String]$Username, # usernname of the linux user running the script
    # [String]$WorkingDirectory = "C:\Minecraft-Server",
    [Switch]$SendMail
)

$WorkingDirectory = Get-Location

# Setting Log Information 
$LogPath = "$WorkingDirectory\logs\"
If(!(test-path $LogPath))
{
      New-Item -ItemType Directory -Force -Path $LogPath
}

$StartTime = Get-Date
$LogFile = $LogPath + $StartTime.ToString("yyyy-MM-dd") + "-minecraf_update.log" # Defining Log name and path
Start-Transcript -Path $LogFile -Force # Starting the LOG
$DebugPreference = 'Continue'
$InformationPreference = 'SilentlyContinue'
$WarningPreference = 'Continue'
$VerbosePreference = 'Continue'


# Checking for available Updates
Write-Verbose -Message "Checking for current version installed"
$local_version = Get-Content -Path "$WorkingDirectory\version.txt"
Write-Verbose -Message "Local version found: $($local_version)"

Write-Verbose -Message "Checking for availabe version online"
$request = Invoke-Webrequest -Uri "https://www.minecraft.net/en-us/download/server/bedrock"

$download_link = $request.Links | ? class -match "btn" | ? href -match "bin-win/bedrock" | select -ExpandProperty href

$online_version = $download_link.split("/")[4].split("-")[2].replace(".zip", "")
Write-Verbose -Message "Online version found: $($online_version)"


# If version is different the update the server
if ($local_version -eq $online_version) {
    Write-Verbose -Message "Local version and Online version are identical. Exiting script"
    exit
}
else {
    # Stopping the Minecraft server
    Write-Verbose -Message "There are difference in Online and Local versions"
    Write-Verbose -Message "Stopping the Minecraft service"
    Stop-Service -Name "minecraft-server"

    start-sleep -s 2

    # Backup the Minecraft server
    Write-Verbose -Message "Initiating server backup"
    if(!(Test-Path -path "$WorkingDirectory/backup")){
        Write-Verbose -Message "Didn't find the Minecraft backup folder. Creating it now"
        New-Item -Path "$WorkingDirectory/backup" -ItemType Directory
    }
    Write-Verbose -Message "Copying the current server into the backup folder"
    $backup_folder = "$WorkingDirectory/backup/bedrock-server-$($local_version)"

    $excludes = "backup", "Downloads", "mincraft-server-updater.ps1"
    Get-ChildItem "$WorkingDirectory" -Directory | 
    Where-Object{$_.Name -notin $excludes} | 
    Copy-Item -Destination $backup_folder -Recurse -Force


    Start-Sleep -s 5

    #Backup First!

    # Compressing the backup server folder
    Write-Verbose -Message "Compressing the backed up server version to conserve space"
    Compress-Archive -Path $backup_folder -DestinationPath "$($backup_folder).zip"
    

    # Removing old server files from $WorkingDirectory
    Write-Warning -Message "Removing the current version of the server!"
    # Remove-Item -Path "$WorkingDirectory" -Recurse -Force

    Get-ChildItem -Path "$WorkingDirectory" -Exclude "backup","Downloads","logs","mincraft-server-updater.ps1" | Remove-Item -Recurse -Force

    
    # Downloading and Extracting the new version of Minecraft
    Write-verbose -Message "Downloading the new version of the server"
    if(!(Test-Path -path "$WorkingDirectory\Downloads")){
        Write-Verbose -Message "Didn't find the Minecraft Download folder. Creating it now"
        New-Item -Path "$WorkingDirectory/Downloads" -ItemType Directory
    }
    Invoke-WebRequest -Uri $download_link -OutFile "$WorkingDirectory\Downloads\bedrock-server.zip"
    Write-Verbose -Message "Expanding the folder to the home folder"
    $new_destination = "$WorkingDirectory" # $WorkingDirectory/
    Expand-Archive -Path "$WorkingDirectory\Downloads\bedrock-server.zip" -DestinationPath $new_destination


    # Copying old Configurations files to the new server
    Write-Verbose -Message "Copying world files into new server"
    Copy-Item "$backup_folder\worlds" -Destination $new_destination -Recurse -Force
    Write-Verbose -Message "Copying permissions file into new server"
    Copy-Item "$backup_folder\permissions.json" -Destination $new_destination -Force
    Write-Verbose -Message "Copying server properties file into new server"
    Copy-Item "$backup_folder\server.properties" -Destination $new_destination -Force
    Write-Verbose -Message "Copying whitelist file into new server"
    Copy-Item "$backup_folder\whitelist.json" -Destination $new_destination -Force
    Write-Verbose -Message "Copying Resource Packs"
    Copy-Item "$backup_folder\resource_packs" -Destination $new_destination -Recurse -Force


    # Creating new Version text file
    Write-Verbose -Message "Creating a new version.txt file"
    $version_file = "$new_destination\version.txt"
    New-Item $version_file -ItemType File -Force
    Add-Content -Path $version_file -Value "$($online_version)" -NoNewline


    # Removing the old uncompressed server files
    # Write-Verbose -Message "Remove uncompressed version of backup server"
    # if(Test-Path "$($backup_folder).zip"){
    #     Remove-Item -Path $backup_folder -Recurse -Force
    #}


    # Setting the new Server Script to be executable and starting the server
    Write-Verbose "Setting new server script to be executable"
    Write-Verbose -Message "Starting the server again"
    Start-Service -Name "minecraft-server"

    # Sending Emails
    if($SendMail.IsPresent){
        $From = bob@pineclose.co.uk # Email address to send mail out with
        $Password = ConvertTo-SecureString "<password>" -AsPlainText -Force # password for the email address to send mail with
        $Creds = New-Object System.Management.Automation.PSCredential ($From, $Password)
        $To = # Array of user emails
        $Subject = "Minecraft Server Update!"
        $Body = "Minecraft Server was updated to version: $($online_version)"
        $SMTPServer = "send.one.com"

        Send-MailMessage -From $From -To $To -Credential $Creds -Subject $Subject -Body $Body -SmtpServer $SMTPServer -UseSsl -Port 587
    }


    # Cleaning up downloaded files
    #if(Test-Path "$WorkingDirectory\Downloads\bedrock-server.zip"){
    #    Remove-Item -Path "$WorkingDirectory\Downloads\bedrock-server.zip" -Force
    #}
}

# Stopping the log file
Stop-Transcript