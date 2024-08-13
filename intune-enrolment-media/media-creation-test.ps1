$TEMPPATH = "C:\$(New-GUID)"
$NEWISONAME = "$TEMPPATH\WindowAutopilot.iso"
$ISOCONTENTS = "$TEMPPATH\iso\"
$INSTALLWIM = "$ISOCONTENTS\sources\install.wim"
$INSTALLWIMTEMP = "$TEMPPATH\installtemp.wim"
$MOUNTDIR = "$TEMPPATH\mount"

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

Write-Host "$AUTOPILOTCONFIG"
Write-Host "$ISO"

## Mount disk image to drive.
Write-Host " Mounting Windows ISO..."
$MOUNTISO = Mount-DiskImage -ImagePath $ISO -StorageType ISO -PassThru
$MOUNTDRIVE = ($MOUNTISO | Get-Volume).DriveLetter
$MOUNTDRIVE = ($MOUNTDRIVE + ":\")

## Extract image indexes from ISO.
$OLDINSTALLWIM = ($MOUNTDRIVE + "sources\install.wim")
Write-Host " Finding images in $OLDINSTALLWIM"
Get-WindowsImage -ImagePath $OLDINSTALLWIM | Select-Object ImageIndex,ImageName | Format-Table
$IMAGEINDEX = $null
while ($IMAGEINDEX -notmatch "^\d+$"){
    $IMAGEINDEX = (Read-Host -Prompt " Enter the Image index number for your desired Windows Image")
}
Write-Host " Chosen $IMAGEINDEX."

## Copy contents of ISO and install.wim for manipulation.
Write-Host " Copying ISO contents to $ISOCONTENTS" -ForegroundColor Yellow
$COPYISOFILES = Copy-Item -Path $MOUNTDRIVE -Destination $ISOCONTENTS -Recurse
Write-Host " Copying completed!" -ForegroundColor Green
Write-Host " Copying temporary install.wim for file manipulation."
$COPYWIM = Copy-Item -Path $INSTALLWIM -Destination $INSTALLWIMTEMP

## Remove read-only flag from installtemp.wim file.
Write-Host " Removing Read-Only flag from installtemp.wim." -ForegroundColor Yellow
Set-ItemProperty -Path $INSTALLWIMTEMP -Name IsReadOnly -Value $false
Write-Host " Flag removed!" -ForegroundColor Green

## Build mount directory.
Write-Host " Creating /mount directory..."
New-Item "$TEMPPATH\mount" -ItemType Directory
Write-Host " Mount folder successfully created!"

## Mount installtemp.wim.
Write-Host " Attempting to mount installtemp.wim..." -ForegroundColor Yellow
Mount-WindowsImage -ImagePath $INSTALLWIMTEMP -Path $MOUNTDIR -Index $IMAGEINDEX
Write-Host " installtemp.wim successfully mounted!" -ForegroundColor Green

## Inject JSON file.
Write-Host " Attempting to inject Autopilot configuration..." -ForegroundColor Yellow
$AUTOPILOTCONFIG | Set-Content -Encoding Ascii "$MOUNTDIR\Windows\Provisioning\Autopilot\AutopilotConfigurationFile.json"
Write-Host " Successfully injected Autopilot configuration!" -ForegroundColor Green

## Remove read-only flag from install.wim file.
Write-Host " Removing Read-Only flag from install.wim." -ForegroundColor Yellow
Set-ItemProperty -Path $INSTALLWIM -Name IsReadOnly -Value $false
Write-Host " Flag removed!" -ForegroundColor Green

## Remove the old install.wim file.
Write-Host " Removing install.wim from \sources..." -ForegroundColor Yellow
Remove-Item $INSTALLWIM
Write-Host " Successfully removed!" -ForegroundColor Green

## Export installtemp.wim to replace install.wim.
Write-Host " Exporting new install.wim to \sources..." -ForegroundColor Yellow
Export-WindowsImage -SourceImagePath $INSTALLWIMTEMP -DestinationImagePath $INSTALLWIM -SourceIndex $IMAGEINDEX
Write-Host " Successfully created!"

## Use oscdimg to create ISO.
Write-Host " Building oscdimg directory..."
New-Item -Path "$TEMPPATH\oscdimg" -ItemType Directory
Write-Host " Directory built!" -ForegroundColor Green

## Use iwr to get file.
$URL = "https://github.com/andrew-s-taylor/oscdimg/archive/main.zip"
$OUTPUT = "$TEMPPATH\oscdimg.zip"
Write-Host " Downloading OSCDIMG..."
Invoke-WebRequest -Uri $URL -Outfile $OUTPUT -Method Get
Write-Host " Download complete!" -ForegroundColor Green

## Unzip oscdimg and remove .zip file.
Write-Host " Unzipping and cleaning .zip..."
Expand-Archive $OUTPUT -DestinationPath "$TEMPPATH\oscdimg" -Force
Write-Host " Unzipped, removing .zip..."
Remove-Item $OUTPUT -Force
Write-Host " .zip file removed!" -ForegroundColor Green

## Create ISO from install image.
Write-Host " Building ISO..." -ForegroundColor Yellow
& "$TEMPPATH\oscdimg\oscdimg-main\oscdimg.exe" -b"$MOUNTDRIVE\efi\microsoft\boot\efisys.bin" -pEF -u1 -udfver102 $ISOCONTENTS $NEWISONAME
Write-Host " $NEWISONAME successfully created!" -ForegroundColor Green

## Cleanup

Write-Host "Ejecting ISO"
$DISMOUNT = Dismount-DiskImage $ISO
Write-Host "ISO ejected."

