## Bootable Meida
## Start Instructions

Clear-Host
Write-Host " To begin, Connect a USB drive of at least 16GB size"
Write-Host " It is recommended you remove all other USB drives!"
Write-Host
Write-Host " Checking for connected disks. This may take a moment..."
Write-Host
Write-Host " The selected disk will be completely formatted!" -BackgroundColor White -ForegroundColor DarkMagenta 
Write-Host " Any data will not be recoverable." -BackgroundColor White -ForegroundColor DarkMagenta 
Write-Host " Ensure you do NOT format your boot drive!" -BackgroundColor White -ForegroundColor DarkMagenta 
Write-Host " If you are unsure, press CTRL + C to abort." -BackgroundColor White -ForegroundColor DarkMagenta 

$COPYAUTOPILOTSCRIPTS = $true
$COPYAUTOPILOTSCRIPTS = "C:\ISO\AutopilotConfigurationFile.json"

if (Test-Path -Path "$COPYAUTOPILOTSCRIPTS") {
    Write-Host "Copying: $COPYAUTOPILOTSCRIPTS"
}

$TEMPPATH = "C:\$(New-GUID)"

## Write out connected disks.

Get-Disk | Format-Table Number, Friendlyname, HealthStatus, PartitionStyle,@{n='Size';e={[int]($_.Size/1GB)}}

## Display disk number and get confirmation of wipe.

$DISKNUMBER = Read-Host -Prompt " Select a disk and press enter to confirm"
CLear-Host
Write-Host " WARNING! The following disk will be erased:" -ForegroundColor Red
Get-Disk $DISKNUMBER | Format-Table Number, Friendlyname, HealthStatus, PartitionStyle,@{n='Size';e={[int]($_.Size/1GB)}}
Write-Host " This cannot be undone!" -ForegroundColor Red

$CONFIRMPROMPT = Read-Host -Prompt " Type 'YES' and press Enter to confirm"
if ($CONFIRMPROMPT -ne "YES") {
    Write-Host " Terminating process..."
    Exit
}

Clear-Host
## Wipe chosen USB
Write-Host " Erasing disk..."
Clear-Disk -Number $DISKNUMBER -RemoveData -Confirm:$false
$BUILDSTICK = New-Partition -DiskNumber $DISKNUMBER -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem FAT32
$BUILDSTICK = ($BUILDSTICK | Get-Volume).DriveLetter
$BUILDSTICK = ($BUILDSTICK + ":\")
Write-Host " Disk formatted successfully!" -ForegroundColor Green
Write-Host

## Get Windows ISO
Clear-Host
$ISO = Read-Host -Prompt " Enter full path to ISO image"
$MOUNTISO = Mount-DiskImage -ImagePath $ISO -StorageType ISO -PassThru
$MOUNTDRIVE = ($MOUNTISO | Get-Volume).DriveLetter
$MOUNTDRIVE = ($MOUNTDRIVE + ":\")

## Extract image indexes from ISO.
$INSTALLWIM = ($MOUNTDRIVE + "sources\install.wim")
Write-Host " Finding images in $INSTALLWIM"
Get-WindowsImage -ImagePath $INSTALLWIM | Select-Object ImageIndex,ImageName | Format-Table
$IMAGEINDEX = $null
while ($IMAGEINDEX -notmatch "^\d+$"){
    $IMAGEINDEX = (Read-Host -Prompt " Enter the Image index number for your desired Windows Image")
}
Write-Host " Chosen $IMAGEINDEX."
Write-Host

## Build temporary workspace to disable read-only flag.
Write-Host " Creating temporary workspace at $TEMPPATH"
New-Item -Path $TEMPPATH -Type directory | Out-Null
New-Item -Path "$TEMPPATH\MOUNT" -Type directory | Out-Null
Write-Host " Workspace built." -ForegroundColor Green
Write-Host " Copying install.wim to $TEMPPATH"
Copy-Item -Path "$INSTALLWIM" -Destination "$($TEMPPATH)\install.wim" -Verbose
$INSTALLWIM = "$TEMPPATH\install.wim"
Set-ItemProperty $INSTALLWIM -Name IsReadOnly -Value $false

## Mount install.wim and copy Autopilot scripts.
Write-Host " Mounting install.wim..."
Mount-WindowsImage -Path "$TEMPPATH\MOUNT" -ImagePath $INSTALLWIM -Index $IMAGEINDEX | Out-Null
Write-Host " Injecting Autopilot configuration..."
$COPYAUTOPILOTSCRIPTS | Set-Content -Encoding Ascii "$TEMPPATH\MOUNT\Windows\Provisioning\Autopilot\AutopilotConfigurationFile.json"
Write-Host " Dismounting install.wim and applying Autopilot configuration..."
Dismount-WindowsImage -Path "$TEMPPATH\MOUNT" -Save
Write-Host " Image dismounted!" -ForegroundColor Green

## Disable read-only flag again and replace old install.wim
Write-Host "Removing read-only property..."
Set-ItemProperty -Path "$TEMPPATH\install.wim" -Name IsReadOnly -Value $false
Write-Host "File is now read/write." -ForegroundColor Green
Write-Host "Removing old install.wim from Source directory..."
Remove-Item -Path ($MOUNTDRIVE + "sources\install.wim")
Write-Host "Old install file removed successfully!" -ForegroundColor Green

## Export new install.wim to Sources.
Write-Host "Exporting configured install.wim to Sources."
Export-WindowsImage -SourceImagePath $INSTALLWIM -DestinationImagePath ($MOUNTDRIVE + "sources\install.wim") -SourceIndex $IMAGEINDEX
Write-Host "Export successful!" -ForegroundColor Green

## Cleanup

if(Test-Path "$TEMPPATH") {
    Write-Output "Deleting $TEMPPATH..."
    Remove-Item -Path $TEMPPATH -Recurse
}

#$FILES = Get-ChildItem -Path $MOUNTDRIVE -Recurse
#$FILECOUNT = $FILES.count
#Write-Host ""
#$i = 0
#Foreach ($FILE in $FILES) {
#    $i++
#    Write-Progress -activity "Copying files to USB..." -status "$FILE ($i of $FILECOUNT)" -percentcomplete (($i/$FILECOUNT)*100)
#    if ($FILE.psiscontainer) {
#        $SOURCEFILECONTAINER = $FILE.parent
#    } else {
#        $SOURCEFILECONTAINER = $FILE.directory
#    }
#    $RELATIVEPATH = $SOURCEFILECONTAINER.fullname.SubString($MOUNTDRIVE.length)
#    Copy-Item $FILE.fullname ($BUILDSTICK + $RELATIVEPATH) -Exclude "install.wim" -Verbose -Force
#}
#
#$WIMSIZE = (Get-Item "$INSTALLWIM").Length
#if ($WIMSIZE -gt 4GB){ 
#    Write-Host "Install.wim is larger than 4GB ($($WIMSiZE / 1GB)), splitting it into SWM files..."
#    Split-WindowsImage -ImagePath $INSTALLWIM -SplitImagePath ($BUILDSTICK + "sources\install.swm") -FileSize 4096 | Out-Null
#} else {
#    Write-Host "Install.wim is smaller than 4GB, copying..."
#    Copy-Item -Path $INSTALLWIM -Destination ($BUILDSTICK + "sources\install.wim")
#}
#
#Write-Host "Drive built!" -ForegroundColor Green