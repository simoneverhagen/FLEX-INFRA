#This script asks for user input
#The user input is used to change property's of the Windows VHD file
#The computername, username and a few settings in Windows are changed with this scipt

#!!!This script requires a specific file structure with predownloaded files. 

# Ask for input
$courseName = Read-Host -Prompt 'Enter the course name'
$studentName = Read-Host -Prompt 'Enter the student name'
$studentNumber = Read-Host -Prompt 'Enter the student number'
$cpu = Read-Host -Prompt 'Enter the number of CPUs'
$ram = Read-Host -Prompt 'Enter the amount of RAM in MB'

# Define paths
$baseDir = "C:\SAX-FLEX-INFRA"
$courseDir = Join-Path -Path $baseDir -ChildPath "Courses\$courseName"
$vhdPath = Join-Path -Path $baseDir -ChildPath 'BASE-FILES\Windows server 2022.vhd'
$newVhdPath = Join-Path -Path $courseDir -ChildPath "$courseName-$studentNumber-vm1.vhd"
$unattendedPath = Join-Path -Path $baseDir -ChildPath 'BASE-FILES\unattend.xml'
$vboxManagePath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

# Create course directory
New-Item -ItemType Directory -Force -Path $courseDir

# Copy and rename VHD
Copy-Item -Path $vhdPath -Destination $newVhdPath

# Mount the VHD
$DriveLetter = (Mount-VHD -Path $newVhdPath -PassThru | Get-Disk | Get-Partition | Get-Volume).DriveLetter

# Create Panther directory
New-Item -ItemType Directory -Force -Path "$($driveLetter):\Windows\Panther"

# Copy and edit Autounattend.xml
$unattendedContent = Get-Content -Path $unattendedPath -Raw
$unattendedContent = $unattendedContent.Replace('var-username', $studentName).Replace('var-pc-name', $studentNumber)
Set-Content -Path "$($driveLetter):\Windows\Panther\unattend.xml" -Value $unattendedContent

# Dismount the VHD
Dismount-DiskImage -ImagePath $newVhdPath

# Change the UUID
& $vboxManagePath internalcommands sethduuid $newVhdPath

# Create a VM
& $vboxManagePath createvm --name "$courseName-$studentNumber-vm1" --ostype="Windows2022_64" --register #test
& $vboxManagePath modifyvm "$courseName-$studentNumber-vm1" --cpus $cpu --memory $ram
& $vboxManagePath storagectl "$courseName-$studentNumber-vm1" --name "SATA Controller" --add sata --controller IntelAhci #test
& $vboxManagePath storageattach "$courseName-$studentNumber-vm1" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $newVhdPath
