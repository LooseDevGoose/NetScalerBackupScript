#Simple script to backup the configuration of a NetScaler and it's partitions
#Written by Mick Hilhorst | m.hilhorst@goose-it.nl | mickhilhorst.com
#Version 1.0

#Set all text to Yellow
$Host.UI.RawUI.ForegroundColor = "Yellow"
# Read user input for NSIP
$NSIP = Read-Host "Enter the NetScaler IP"
# Read user input for Username
$USERNAME = Read-Host "Enter the Username"
# Read user input for Password
$PASSWORD = Read-Host "Enter the Password" -AsSecureString

# Create a credential object
$Cred = New-Object System.Management.Automation.PSCredential ($USERNAME, $PASSWORD)

# Specify the URL for the API login
$URL = "https://$($NSIP)/nitro/v1/config/login"

# Create body for the API login
$body = @{
    login = @{
        # use the username from the credential object
        username = $Cred.UserName
        # use the password from the credential object
        password = $Cred.Password | ConvertFrom-SecureString -AsPlainText
    }
}
try {
    # Store the session ID in a variable for all future API calls
    $id = Invoke-RestMethod -Method POST -Uri $url -Body (ConvertTo-Json $body) -ContentType "application/json" -SkipCertificateCheck
    Write-Host "Login Successful" -ForegroundColor Green
    
} catch {
    Write-Host "Login Failed: $($_)" -ForegroundColor Red
}
        
# Get all NetScaler Partitions
$url = "https://$($NSIP)/nitro/v1/config/nspartition"
$headers = @{
    "Cookie" = "NITRO_AUTH_TOKEN=$($id.sessionid)"
}

try {
    $PresentPartitions = Invoke-RestMethod -Uri $URL -headers $headers -Method Get -ContentType "application/json" -SkipCertificateCheck
} catch {
    Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Display all partitions in $presentpartitions
Write-Host -ForegroundColor Green "The following partitions have been found on the NetScaler:"
foreach ($Partition in $PresentPartitions.nspartition) {
    Write-Host $Partition.partitionname
}
        
#Create folder in PSscriptroot and give it the current date and time
$folder = New-Item -Path "$($PSScriptRoot)\$((Get-Date).ToString('yyyy-MM-dd_HH-mm-ss'))" -ItemType Directory

#Retrieve the primary ns.conf file
try{
    Write-Host -ForegroundColor Green "Retrieving the main ns.conf file"
    $path = "/nsconfig/partitions/coding_partition"
    $escapedLocation = [System.Uri]::EscapeDataString("/nsconfig/")
    $url = "https://$($NSIP)/nitro/v1/config/systemfile?args=filelocation:$($escapedLocation),filename:ns.conf"
    $file = Invoke-RestMethod -Uri $URL -headers $headers -Method Get -ContentType "application/json" -SkipCertificateCheck
    Set-Content -Path "$($folder.FullName)\ns.conf" -Value ([System.Convert]::FromBase64String($file.systemfile.filecontent)) -Force -AsByteStream
}catch{
    Write-Host -ForegroundColor Red "Failed to retrieve the main ns.conf file"
}


#Retrieve all the partition configuration files
Write-Host -ForegroundColor Green "Retrieving the partition configuration files"
foreach ($Partition in $PresentPartitions.nspartition){
    try{
        Write-Host  -ForegroundColor Yellow "Creating backup for $($Partition.partitionname).."
        #Translate the partition name to a URL friendly format
        $escapedLocation = [System.Uri]::EscapeDataString("/nsconfig/partitions/$($Partition.partitionname)")

        #Retrieve the partition configuration file
        $url = "https://$($NSIP)/nitro/v1/config/systemfile?args=filelocation:$($escapedLocation),filename:ns.conf"
        $file = Invoke-RestMethod -Uri $URL -headers $headers -Method Get -ContentType "application/json" -SkipCertificateCheck

        #Create a folder for the partition
        New-Item -Path "$($folder.FullName)\$($Partition.partitionname)" -ItemType Directory | Out-Null

        #Write (/translate) the content of the file to the folder
        Set-Content -Path "$($folder.FullName)\$($Partition.partitionname)\ns.conf" -Value ([System.Convert]::FromBase64String($file.systemfile.filecontent)) -Force -AsByteStream
    Write-Host  -ForegroundColor Green "Backup created for $($Partition.partitionname)"
    }catch{
        Write-Host  -ForegroundColor Red "Failed to create backup for $($Partition.partitionname)"
    }
}

#Report the location of the backup folder
Write-Host -ForegroundColor Magenta "Done! Backups created in $($folder.FullName)!"

