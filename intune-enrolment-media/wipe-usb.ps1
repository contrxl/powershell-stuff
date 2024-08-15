## Bootable Meida
## Start Instructions

Clear-Host
Write-Host " To begin, Connect a USB drive of at least 16GB size"
Write-Host " It is recommended you remove all other USB drives!"
Write-Host
Write-Host " Checking for connected disks. This may take a moment..."
Write-Host
Write-Host " The selected disk will be completely erased!" -BackgroundColor White -ForegroundColor DarkMagenta 
Write-Host " Any data will not be recoverable." -BackgroundColor White -ForegroundColor DarkMagenta 
Write-Host " Ensure you do NOT format your boot drive!" -BackgroundColor White -ForegroundColor DarkMagenta 
Write-Host " If you are unsure, press CTRL + C to abort." -BackgroundColor White -ForegroundColor DarkMagenta 

$COPYAUTOPILOTSCRIPTS = $true
$COPYAUTOPILOTSCRIPTS = "C:\ISO\AutopilotConfigurationFile.json"

if (Test-Path -Path "$COPYAUTOPILOTSCRIPTS") {
    Write-Host "Copying: $COPYAUTOPILOTSCRIPTS"
}

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
$BUILDSTICK = New-Partition -DiskNumber $DISKNUMBER -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS
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

$FILES = Get-ChildItem -Path $MOUNTDRIVE -Recurse
$FILECOUNT = $FILES.count
Write-Host ""
$i = 0
Foreach ($FILE in $FILES) {
    $i++
    Write-Progress -activity "Copying files to USB..." -status "$FILE ($i of $FILECOUNT)" -percentcomplete (($i/$FILECOUNT)*100)
    if ($FILE.psiscontainer) {
        $SOURCEFILECONTAINER = $FILE.parent
    } else {
        $SOURCEFILECONTAINER = $FILE.directory
    }
    $RELATIVEPATH = $SOURCEFILECONTAINER.fullname.SubString($MOUNTDRIVE.length)
    Copy-Item $FILE.fullname ($BUILDSTICK + $RELATIVEPATH) -Verbose -Force
}


Write-Host "Drive built!" -ForegroundColor Green