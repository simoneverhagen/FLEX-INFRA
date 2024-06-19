# Code by Matthias

# Path to the files that store name and student number
$studentNameFilePath = "$env:Public\student_name.txt"
$studentNumberFilePath = "$env:Public\student_number.txt"

# Check if name is already stored
if (Test-Path $studentNameFilePath) {
    $studentName = (Get-Content $studentNameFilePath -Raw).Trim()
} else {
    # Introductory text
    Write-Host "Welcome to the SAX-FLEX-INFRA script!"
    Write-Host "This script will help you setup Virtual Machines"
    Write-Host "The script will also configure some properties of the VM's"
    Write-Host "For the configuration we need your name and student number"
    Write-Host "This script is a project from students: Stefan, Luca, Simone, Ahmed and Matthias"

    # Prompt for student name
    $studentName = (Read-Host "Please enter your name").Trim()

    # Save the student name
    Set-Content -Path $studentNameFilePath -Value $studentName
}

# Check if student number is already stored
if (Test-Path $studentNumberFilePath) {
    $studentNumber = (Get-Content $studentNumberFilePath -Raw).Trim()
} else {
    # Ask for the student number
    $studentNumber = (Read-Host "Please enter your student number").Trim()

    # Save the student number
    Set-Content -Path $studentNumberFilePath -Value $studentNumber
}

# Create an ArrayList
$courses = New-Object System.Collections.ArrayList

# Define the GitHub API URL for the directory
$url = "https://api.github.com/repos/Matthias-Schulski/saxion-flex-infra/contents/courses"

# Use Invoke-WebRequest to call the GitHub API
$response = Invoke-WebRequest -Uri $url -Headers @{ "User-Agent" = "Mozilla/5.0" }

# Parse the JSON response
$content = $response.Content | ConvertFrom-Json

# Extract course names from the JSON response
foreach ($item in $content) {
    if ($item.type -eq "file") {
        $courses.Add($item.name) | Out-Null
    }
}

# Check if any courses were found
if ($courses.Count -eq 0) {
    Write-Host "No courses found. Please check the URL or the GitHub repository structure."
    exit
}

# Display the menu to the user
Write-Host "Please choose a course by entering the corresponding number:"
for ($i = 0; $i -lt $courses.Count; $i++) {
    Write-Host "$($i + 1). $($courses[$i])"
}

# Get the user choice
$userChoice = Read-Host "Enter the number corresponding to your choice"

# Convert user choice to zero-based index
$userChoiceIndex = [int]$userChoice - 1

# Validate user input
if ([int]::TryParse($userChoice, [ref]$null) -and $userChoiceIndex -ge 0 -and $userChoiceIndex -lt $courses.Count) {
    # Print the chosen course URL
    $chosenCourse = $courses[$userChoiceIndex]
    [string]$ConfigUrl = "https://github.com/Matthias-Schulski/saxion-flex-infra/blob/main/courses/$chosenCourse"
    Write-Host "You have chosen: $ConfigUrl"
} else {
    Write-Host "Invalid choice. Please run the script again and enter a valid number."
}

# Temporary Execution Policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Variabele voor config script
[string]$VHDLinksUrl = "https://raw.githubusercontent.com/Matthias-Schulski/saxion-flex-infra/main/courses/harddisks.json"

#Code by Stefan
# Functie om een bestand te downloaden
function Download-File {
    param (
        [string]$url,
        [string]$output
    )
    try {
        $client = New-Object System.Net.WebClient
        $client.DownloadFile($url, $output)
        Write-Output "Downloaded file from $url to $output"
    } catch {
        Write-Output "Failed to download file from $url to $output"
        throw
    }
}

# Functie om het OS-type te bepalen
function Get-OSType {
    param (
        [string]$platform,
        [string]$distroName
    )
    if ($platform -eq "Linux") {
        if ($distroName -match "Ubuntu") {
            return "Ubuntu_64"
        } elseif ($distroName -match "Debian") {
            return "Debian_64"
        } elseif ($distroName -match "Alpine") {
            return "Alpine_64"
        } else {
            return "OtherLinux_64"
        }
    } elseif ($platform -eq "Windows") {
        return "Windows"
    } else {
        return "Unknown"
    }
}

# Controleer of het script opnieuw gestart moet worden
$restartFlagFile = "$env:Public\restart_flag.txt"

if (-not (Test-Path $restartFlagFile)) {
    ###########################ALGEMEEN#########################

    # Installatie van PowerShell 7
    [string]$InstallPowershell7ScriptUrl = "https://raw.githubusercontent.com/Matthias-Schulski/saxion-flex-infra/main/infra/main/pwsh7install.ps1"
    $installPowershell7ScriptPath = "$env:Public\Downloads\InstallPowershell7.ps1"

    # Download en voer het PowerShell 7 installatie script uit
    Download-File -url $InstallPowershell7ScriptUrl -output $installPowershell7ScriptPath
    & powershell -File $installPowershell7ScriptPath

    # Maak een flag-bestand om aan te geven dat de installatie van PowerShell 7 voltooid is
    New-Item -ItemType File -Path $restartFlagFile

    # Herstart PowerShell met pwsh
    Start-Process pwsh -ArgumentList "-NoExit", "-File `"$PSCommandPath`""
    exit
} else {
    # Verwijder het flag-bestand
    Remove-Item $restartFlagFile
}

# Installeer Dependencies
[string]$GeneralScriptUrl = "https://raw.githubusercontent.com/Matthias-Schulski/saxion-flex-infra/main/infra/InstallDependencies.ps1"
$generalScriptPath = "$env:Public\Downloads\GeneralScript.ps1"
Download-File -url $GeneralScriptUrl -output $generalScriptPath
& pwsh -File $generalScriptPath

# Download de JSON-bestanden
$configLocalPath = "$env:Public\Downloads\config.json"
$vhdLinksLocalPath = "$env:Public\Downloads\vhdlinks.json"
Download-File -url $ConfigUrl -output $configLocalPath
Download-File -url $VHDLinksUrl -output $vhdLinksLocalPath

# Lees de JSON configuratie
$config = Get-Content $configLocalPath -Raw | ConvertFrom-Json
$vhdLinks = Get-Content $vhdLinksLocalPath -Raw | ConvertFrom-Json

# Map to store OS to VHD URL
$vhdUrlMap = @{}
foreach ($vhdLink in $vhdLinks) {
    $osKey = "{0} {1} {2} {3}" -f $vhdLink.Platform, $vhdLink.DistroName, $vhdLink.DistroVariant, $vhdLink.DistroVersion
    $vhdUrlMap[$osKey] = $vhdLink.VHDUrl
}

# Haal de CourseName op uit de configuratie
$courseName = $config.CourseName.Trim()

# Controleer welke OS'en in de configuratie staan en roep de juiste scripts aan
$hasLinux = $false
$hasWindows = $false

foreach ($vm in $config.VMs) {
    if ($vm.Platform -eq "Linux") {
        $hasLinux = $true
    } elseif ($vm.Platform -eq "Windows") {
        $hasWindows = $true
    }
}

if ($hasLinux) {
    ############################LINUX############################
    $linuxMainScriptUrl = "https://raw.githubusercontent.com/Stefanfrijns/HBOICT/main/test6/linuxmain.ps1"
    $linuxMainScriptPath = "$env:Public\Downloads\LinuxMainScript.ps1"
    Download-File -url $linuxMainScriptUrl -output $linuxMainScriptPath

    foreach ($vm in $config.VMs) {
        if ($vm.Platform -eq "Linux") {
            $vmName = ("{0}_{1}_{2}" -f $courseName, $vm.VMName.Trim(), $studentNumber)
            $osTypeKey = "{0} {1} {2} {3}" -f $vm.Platform, $vm.DistroName, $vm.DistroVariant, $vm.DistroVersion
            $VHDUrl = $vhdUrlMap[$osTypeKey]
            if (-not $VHDUrl) {
                Write-Output "VHD URL not found for $osTypeKey. Skipping VM creation for $vmName."
                continue
            }
            $OSType = Get-OSType -platform $vm.Platform -distroName $vm.DistroName
            $MemorySize = $vm.VMMemorySize
            $CPUs = $vm.VMCpuCount
            $NetworkTypes = $vm.VMNetworkTypes
            $Applications = $vm.VMApplications -join ','

            # Construeer de argumenten voor netwerktypes en subnetten
            $networkTypeArgs = @()
            foreach ($networkType in $NetworkTypes) {
                $subnet = $config.EnvironmentVariables.Subnets | Where-Object { $_.Name -eq $networkType }
                $networkTypeArgs += @{
                    "Type" = $subnet.Type
                    "AdapterName" = $subnet.AdapterName
                    "Network" = $subnet.Network
                }
            }

            # Debug output for network types
            Write-Output "Network Types for VM:"
            $networkTypeArgs | ForEach-Object { Write-Output " - Type: $($_.Type), AdapterName: $($_.AdapterName), Network: $($_.Network)" }

            # Roep het Linux hoofscript aan met de juiste parameters
            $arguments = @(
                "-VMName", $vmName,
                "-VHDUrl", $VHDUrl,
                "-OSType", $OSType,
                "-MemorySize", $MemorySize,
                "-CPUs", $CPUs,
                "-NetworkTypes", ($networkTypeArgs | ConvertTo-Json -Compress),
                "-Applications", $Applications,
                "-ConfigureNetworkPath", $linuxMainScriptPath,
                "-DistroName", $vm.DistroName
            )
            & pwsh -File $linuxMainScriptPath @arguments
        }
    }
}

if ($hasWindows) {
    ###########################WINDOWS###########################
    $windowsMainScriptUrl = "https://raw.githubusercontent.com/Matthias-Schulski/saxion-flex-infra/main/infra/windows/osdeployment/WindowsDeployment.ps1"
    $windowsMainScriptPath = "$env:Public\Downloads\WindowsDeployment.ps1"
    Download-File -url $windowsMainScriptUrl -output $windowsMainScriptPath

    foreach ($vm in $config.VMs) {
        if ($vm.Platform -eq "Windows") {
            $vmName = ("{0}_{1}_{2}" -f $courseName, $vm.VMName.Trim(), $studentNumber)
            $osTypeKey = "{0} {1} {2} {3}" -f $vm.Platform, $vm.DistroName, $vm.DistroVariant, $vm.DistroVersion
            $VHDUrl = $vhdUrlMap[$osTypeKey]
            if (-not $VHDUrl) {
                Write-Output "VHD URL not found for $osTypeKey. Skipping VM creation for $vmName."
                continue
            }
            $OSType = Get-OSType -platform $vm.Platform -distroName $vm.DistroName
            $MemorySize = $vm.VMMemorySize
            $CPUs = $vm.VMCpuCount
            $NetworkType = $vm.VMNetworkType
            $Applications = $vm.VMApplications -join ','

            # Haal het subnet op
            $subnet = $config.EnvironmentVariables.Subnets | Where-Object { $_.Name -eq $NetworkType }

            $arguments = @(
                "-VMName", $vmName,
                "-VHDUrl", $VHDUrl,
                "-OSType", $OSType,
                "-MemorySize", $MemorySize,
                "-CPUs", $CPUs,
                "-NetworkType", $subnet.Type,
                "-AdapterName", $subnet.AdapterName,
                "-SubnetNetwork", $subnet.Network,
                "-Applications", $Applications
            )
            & pwsh -File $windowsMainScriptPath @arguments
        }
    }
}

# Herstel de oorspronkelijke Execution Policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

Write-Output "Script execution completed successfully."
