## Initialize variables.

$TEMPPATH = "C:\$(New-GUID)"
$NEWISONAME = "$TEMPPATH\WindowAutopilot.iso"
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
Dismount-DiskImage $ISO
Write-Host " [+] ISO ejected." -ForegroundColor Green
Write-Host

Write-Host " [*] Dismounting install.wim."
DISM /Unmount-WIM /mountdir:$MOUNTDIR /discard
Write-Host " [+] Image dismounted." -ForegroundColor Green
Write-Host

Write-Host " [*] Removing temporary install.wim."
Remove-Item $INSTALLWIMTEMP
Write-Host " [+] Removed." -ForegroundColor Green
Write-Host

Write-Host " [*] Removing extracted ISO contents."
Remove-Item $ISOCONTENTS -Recurse -Force
Write-Host " [+] Removed." -ForegroundColor Green

Write-Host " [*] Removing mount folder."
Remove-Item "$TEMPPATH\MOUNT" -Recurse -Force
Write-Host " [+] Removed." -ForegroundColor Green

Write-Host " [*] Removing oscdimg folder."
Remove-Item "$TEMPPATH\oscdimg" -Recurse -Force
Write-Host " [+] Removed." -ForegroundColor Green

Write-Host " [+] ISO successfully built." -ForegroundColor Green