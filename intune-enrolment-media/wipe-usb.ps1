## Bootable Meida
## Start Instructions
$TEMPPATH = "C:\$(New-GUID)"


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

## Write out connected disks.

Get-Disk | Format-Table Number, Friendlyname, HealthStatus, PartitionStyle,@{n='Size';e={[int]($_.Size/1GB)}}

## Display disk number and get confirmation of wipe.

$DISKNUMBER = Read-Host -Prompt " [*] Select a disk and press enter to confirm"
CLear-Host
Write-Host " [!] WARNING! The following disk will be erased:" -ForegroundColor Red
Get-Disk $DISKNUMBER | Format-Table Number, Friendlyname, HealthStatus, PartitionStyle,@{n='Size';e={[int]($_.Size/1GB)}}
Write-Host " [!] This cannot be undone!" -ForegroundColor Red

$CONFIRMPROMPT = Read-Host -Prompt " Type 'YES' and press Enter to confirm"
if ($CONFIRMPROMPT -ne "YES") {
    Write-Host " [-] Terminating process..." -ForegroundColor Red
    Exit
}

Clear-Host
## Wipe chosen USB
Write-Host " [*] Erasing disk..."
Clear-Disk -Number $DISKNUMBER -RemoveData -Confirm:$false
$BUILDSTICKA = New-Partition -DiskNumber $DISKNUMBER -Size 4gb -AssignDriveLetter | Format-Volume -FileSystem NTFS
$BUILDSTICKA = ($BUILDSTICKA | Get-Volume).DriveLetter
$BUILDSTICKA = ($BUILDSTICKA + ":\")
$BUILDSTICKB = New-Partition -DiskNumber $DISKNUMBER -Size 8gb -AssignDriveLetter | Format-Volume -FileSystem NTFS
$BUILDSTICKB = ($BUILDSTICKB | Get-Volume).DriveLetter
$BUILDSTICKB = ($BUILDSTICKB + ":\")

Write-Host " [+] Disk formatted successfully!" -ForegroundColor Green
Write-Host " [+] Created partitions $BUILDSTICKA and $BUILDSTICKB" -ForegroundColor Green
Write-Host

## Use new net object to get file.
$URLPE = "https://githublfs.blob.core.windows.net/storage/WinPE.zip"
$OUTPUTPE = "C:\WinPE.zip"
Write-Host " [*] Downloading WinPE..."
Write-Verbose " [*] Downloading from $URLPE and outputting to $OUTPUTPE."
Write-Host " [*] This may take a few minutes..."
$DOWNLOADPE = New-Object net.webclient
$DOWNLOADPE.Downloadfile($URLPE, $OUTPUTPE)
Write-Host " [+] Download complete!" -ForegroundColor Green

## Unzip WinPE and remove .zip file.
Write-Host " [*] Unzipping and cleaning .zip..."
Write-Verbose " [*] Unzipping file located at $OUTPUTPE."
Expand-Archive $OUTPUTPE -DestinationPath "$TEMPPATH\WinPE" -Force
Write-Host " [*] Unzipped, removing .zip..."
Write-Verbose " [+] Unzipped to C:\WinPE."
Remove-Item $OUTPUTPE -Force
Write-Host " [+] .zip file removed!" -ForegroundColor Green
Write-Verbose " [+] .zip file removed from $OUTPUTPE."

### Get Windows ISO
#Clear-Host
#$ISO = Read-Host -Prompt " Enter full path to ISO image"
#$MOUNTISO = Mount-DiskImage -ImagePath $ISO -StorageType ISO -PassThru
#$MOUNTDRIVE = ($MOUNTISO | Get-Volume).DriveLetter
#$MOUNTDRIVE = ($MOUNTDRIVE + ":\")
#
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
#    Copy-Item $FILE.fullname ($BUILDSTICK + $RELATIVEPATH) -Verbose -Force
#}
#
#
#Write-Host "Drive built!" -ForegroundColor Green