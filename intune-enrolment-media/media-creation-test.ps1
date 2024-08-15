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

## Write out connected disks.

Get-Disk | Format-Table Number, Friendlyname, HealthStatus, PartitionStyle,@{n='Size';e={[int]($_.Size/1GB)}}

## Display disk number and get confirmation of wipe.

$DISKNUMBER = Read-Host -Prompt " Select a disk and press enter to confirm"
Write-Host " WARNING! The following disk will be erased:" -ForegroundColor Red
Get-Disk $DISKNUMBER | Format-Table Number, Friendlyname, HealthStatus, PartitionStyle,@{n='Size';e={[int]($_.Size/1GB)}}
Write-Host " This cannot be undone!" -ForegroundColor Red

$CONFIRMPROMPT = Read-Host -Prompt " Type 'YES' and press Enter to confirm"
if ($CONFIRMPROMPT -ne "YES") {
    Write-Host " Terminating process..."
    Exit
}

## Wipe chosen USB
Write-Host " Erasing disk..."
Clear-Disk -Number $DISKNUMBER -RemoveData -Confirm:$false
$BUILDSTICK = New-Partition -DiskNumber $DISKNUMBER -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS
$BUILDSTICK = ($BUILDSTICK | Get-Volume).DriveLetter
$BUILDSTICK = ($BUILDSTICK + ":\")
Write-Host " Disk formatted successfully!" -ForegroundColor Green
Write-Host

## Initialize variables.

$TEMPPATH = "C:\$(New-GUID)"
$NEWISONAME = "$TEMPPATH\WindowsAutopilot.iso"
$ISOCONTENTS = "$TEMPPATH\iso\"
$INSTALLWIM = "$ISOCONTENTS\sources\install.wim"
$INSTALLWIMTEMP = "$TEMPPATH\installtemp.wim"
$MOUNTDIR = "$TEMPPATH\mount"

<#
.SYNOPSIS
A function to validate that any user-provided paths are actually valid.
Needed to ensure that AutoPilot config and ISO paths are valid file paths and not junk.

.DESCRIPTION
Long description

.PARAMETER VALIDNAME
VALIDNAME is the name of the path being validated.

.PARAMETER VALIDATE
VALIDATE is the full path to test.

.EXAMPLE
validatePath("My file","C:\MyFolder\MyFile")
#>
function validatePath([string]$VALIDNAME,[string]$VALIDATE) {
    $EXISTS = $false
    while (-not $EXISTS) {
        $VALIDNAME = $VALIDNAME.Trim()
        $VALIDATE = Read-Host -Prompt " [*] Enter full path to $VALIDNAME"
        if (Test-Path -Path "$VALIDATE") {
            Write-Host " [+] Path valid!" -ForegroundColor Green
            Write-Verbose " [+] Path validated at $VALIDATE"
            return "$VALIDATE"
        } else {
            Write-Host " [-] Path invalid!" -ForegroundColor Red
        }
    }
}
$AUTOPILOTCONFIG = validatePath("AutoPilot Configuration file","$AUTOPILOTCONFIG")
$ISO = validatePath("ISO file", "$ISO")

## Try to mount disk image to drive.
try {
    Write-Host " [*] Mounting Windows ISO..."
    $MOUNTISO = Mount-DiskImage -ImagePath $ISO -StorageType ISO -PassThru
    $MOUNTDRIVE = ($MOUNTISO | Get-Volume).DriveLetter
    $MOUNTDRIVE = ($MOUNTDRIVE + ":\")
} catch {
    Write-Error " [-] Failed to mount ISO."
}
Write-Host " [+] ISO successfully mounted at $MOUNTDRIVE."
Write-Host

## Extract image indexes from ISO.
$OLDINSTALLWIM = ($MOUNTDRIVE + "sources\install.wim")
Write-Verbose " [*] Original install.wim located at $OLDINSTALLWIM."
Write-Host " [*] Finding images in $OLDINSTALLWIM." 
Get-WindowsImage -ImagePath $OLDINSTALLWIM | Select-Object ImageIndex,ImageName | Format-Table
$IMAGEINDEX = $null
while ($IMAGEINDEX -notmatch "^\d+$"){
    $IMAGEINDEX = (Read-Host -Prompt " [+] Enter the Image index number for your desired Windows Image")
}
Write-Host " [+} Using image index: $IMAGEINDEX." -ForegroundColor Green

## Copy contents of ISO and install.wim for manipulation.
Write-Host " [*] Copying ISO contents to $ISOCONTENTS."
Copy-Item -Path $MOUNTDRIVE -Destination $ISOCONTENTS -Recurse
Write-Host " [+] Copying completed!" -ForegroundColor Green
Write-Host " [*] Copying temporary install.wim for file manipulation."
Copy-Item -Path $INSTALLWIM -Destination $INSTALLWIMTEMP
Write-Host " [+] copying completed!" -ForegroundColor Green

## Remove read-only flag from installtemp.wim file.
Write-Host " [*] Removing Read-Only flag from installtemp.wim."
Set-ItemProperty -Path $INSTALLWIMTEMP -Name IsReadOnly -Value $false
Write-Host " [+] Flag removed!" -ForegroundColor Green

## Build mount directory.
Write-Host " [*] Creating /mount directory..."
New-Item "$TEMPPATH\mount" -ItemType Directory
Write-Host " [+] Mount folder successfully created!" -ForegroundColor Green
Write-Verbose " [+] Folder created at $MOUNTDIR."

## Mount installtemp.wim.
Write-Host " [*] Attempting to mount installtemp.wim..."
Mount-WindowsImage -ImagePath $INSTALLWIMTEMP -Path $MOUNTDIR -Index $IMAGEINDEX
Write-Host " [+] installtemp.wim successfully mounted!" -ForegroundColor Green
Write-Verbose " [+] installtemp.wim mounted at $MOUNTDIR."

## Inject JSON file.
Write-Host " [*] Attempting to inject Autopilot configuration..."
$AUTOPILOTCONFIG | Set-Content -Encoding Ascii "$MOUNTDIR\Windows\Provisioning\Autopilot\AutopilotConfigurationFile.json"
Write-Host " [+] Successfully injected Autopilot configuration!" -ForegroundColor Green
Write-Verbose " [+] AutoPilot file injected at $MOUNTDIR\Windows\Provisioning\Autopilot\AutopilotConfigurationFile.json"

## Remove read-only flag from install.wim file.
Write-Host " [*] Removing Read-Only flag from install.wim." 
Set-ItemProperty -Path $INSTALLWIM -Name IsReadOnly -Value $false
Write-Host " [+] Flag removed!" -ForegroundColor Green

## Remove the old install.wim file.
Write-Host " [*] Removing install.wim from \sources..."
Remove-Item $INSTALLWIM
Write-Host " [+] Successfully removed!" -ForegroundColor Green

## Export installtemp.wim to replace install.wim.
Write-Host " [*] Exporting new install.wim to \sources..."
Export-WindowsImage -SourceImagePath $INSTALLWIMTEMP -DestinationImagePath $INSTALLWIM -SourceIndex $IMAGEINDEX
Write-Host " [+] Successfully created!" -ForegroundColor Green

## Use oscdimg to create ISO.
Write-Host " [*] Building oscdimg directory..."
New-Item -Path "$TEMPPATH\oscdimg" -ItemType Directory
Write-Host " [+] Directory built!" -ForegroundColor Green

## Use iwr to get file.
$URL = "https://github.com/andrew-s-taylor/oscdimg/archive/main.zip"
$OUTPUT = "$TEMPPATH\oscdimg.zip"
Write-Host " [*] Downloading OSCDIMG..."
Write-Verbose " [*] Downloading from $URL and outputting to $OUTPUT."
Invoke-WebRequest -Uri $URL -Outfile $OUTPUT -Method Get
Write-Host " [+] Download complete!" -ForegroundColor Green

## Unzip oscdimg and remove .zip file.
Write-Host " [*] Unzipping and cleaning .zip..."
Write-Verbose " [*] Unzipping file located at $OUTPUT."
Expand-Archive $OUTPUT -DestinationPath "$TEMPPATH\oscdimg" -Force
Write-Host " [*] Unzipped, removing .zip..."
Write-Verbose " [+] Unzipped to $TEMPPATH\oscdimg."
Remove-Item $OUTPUT -Force
Write-Host " [+] .zip file removed!" -ForegroundColor Green
Write-Verbose " [+] .zip file removed from $OUTPUT."

## Create ISO from install image.
Write-Host " [*] Building ISO..."
& "$TEMPPATH\oscdimg\oscdimg-main\oscdimg.exe" -b"$MOUNTDRIVE\efi\microsoft\boot\efisys.bin" -pEF -u1 -udfver102 $ISOCONTENTS $NEWISONAME
Write-Host " [+] $NEWISONAME successfully created!" -ForegroundColor Green

## Cleanup

Write-Host " [*] Ejecting ISO."
if (Test-Path $ISO){ 
    Dismount-DiskImage $ISO
    Write-Host " [+] ISO ejected." -ForegroundColor Green
    Write-Host
} else {
    Write-Host " [+] ISO not mounted. Continuing..." -ForegroundColor Green
    Write-Host
    Continue
}

Write-Host " [*] Dismounting install.wim."
DISM /Unmount-WIM /mountdir:$MOUNTDIR /discard
Write-Host " [+] Image dismounted." -ForegroundColor Green
Write-Host

Write-Host " [*] Removing temporary install.wim."
if (Test-Path $INSTALLWIMTEMP) {
    Remove-Item $INSTALLWIMTEMP
    Write-Host " [+] Removed." -ForegroundColor Green
    Write-Host
} else {
    Write-Host " [+] Temporary install.wim not found. Continuing..." -ForegroundColor Green
    Write-Host
    Continue
}

Write-Host " [*] Removing extracted ISO contents."
if (Test-Path $ISOCONTENTS) {
    Remove-Item $ISOCONTENTS -Recurse -Force
    Write-Host " [+] Removed." -ForegroundColor Green
    Write-Host
} else {
    Write-Host " [+] ISO contents not found. Continuing..." -ForegroundColor Green
    Write-Host
    Continue
}
    
Write-Host " [*] Removing mount folder."
if (Test-Path "$TEMPPATH\mount") {
    Remove-Item "$TEMPPATH\mount" -Recurse -Force
    Write-Host " [+] Removed." -ForegroundColor Green
    Write-Host
} else {
    Write-Host " [+] Mount directory not found. Continuing..." -ForegroundColor Green
    Write-Host
    Continue
}
    
Write-Host " [*] Removing oscdimg folder."
if (Test-Path "$TEMPPATH\oscdimg") {
    Remove-Item "$TEMPPATH\oscdimg" -Recurse -Force
    Write-Host " [+] Removed." -ForegroundColor Green        
    Write-Host
} else {
    Write-Host " [+] OSCDIMG directory not found. Continuing..." -ForegroundColor Green
    Write-Host
    Continue
}

Write-Host " [+] ISO successfully built." -ForegroundColor Green

$AUTOPILOTISO = "$TEMPPATH\WindowsAutopilot.iso"
$MOUNTAUTOPILOT = Mount-DiskImage -ImagePath $AUTOPILOTISO -StorageType ISO -PassThru
$MOUNTDRIVE = ($MOUNTAUTOPILOT | Get-Volume).DriveLetter
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
    Copy-Item $FILE.fullname ($BUILDSTICK + $RELATIVEPATH) -Force
}


Write-Host "Drive built!" -ForegroundColor Green