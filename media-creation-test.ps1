$COPYAUTOPILOTSCRIPTS = $true
$COPYAUTOPILOTSCRIPTS = "C:\ISO\AutopilotConfigurationFile.json"

if (Test-Path -Path "$COPYAUTOPILOTSCRIPTS") {
    Write-Host " Autopilot trigger enabled! Copying from: $COPYAUTOPILOTSCRIPTS" -ForegroundColor Yellow
}

$ISO = Read-Host -Prompt " Enter full path to ISO image"

$TEMPPATH = "C:\$(New-GUID)"
$NEWISONAME = "$TEMPPATH\WindowAutopilot.iso"
$ISOCONTENTS = "$TEMPPATH\iso\"
$INSTALLWIM = "$ISOCONTENTS\sources\install.wim"
$INSTALLWIMTEMP = "$TEMPPATH\installtemp.wim"
$MOUNTDIR = "$TEMPPATH\mount"

## Mount disk image to drive.
Write-Host "Mounting Windows ISO..."
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
$COPYAUTOPILOTSCRIPTS | Set-Content -Encoding Ascii "$MOUNTDIR\Windows\Provisioning\Autopilot\AutopilotConfigurationFile.json"
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

## Cleanup

if(Test-Path "$TEMPPATH") {
    Write-Output "Deleting $TEMPPATH..."
    Remove-Item -Path $TEMPPATH -Recurse
}
