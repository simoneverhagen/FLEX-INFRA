#Code by Simone

#parameter van de applicaties
param (
    [string]$JsonFilePath = "C:/Windows/Setup/Applications/VMApplications.json"
)

# Controleer of Chocolatey is geïnstalleerd
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey is not installed. Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Failed to install Chocolatey. Exiting script."
        exit 1
    }
}

# Functie om te controleren of een applicatie is geïnstalleerd met Chocolatey
function Is-AppInstalled {
    param (
        [string]$AppName    
    )
    
    $installedApps = choco list --localonly | Select-String -Pattern $AppName
    return $installedApps -ne $null
}

# Functie om een applicatie te installeren met Chocolatey
function Install-ChocoApp {
    param (
        [string]$AppName
    )
    
    if (Is-AppInstalled -AppName $AppName) {
        Write-Host "$AppName is already installed. Skipping."
    } else {
        try {
            choco install $AppName -y --no-progress
            if ($LASTEXITCODE -eq 0) {
                Write-Host "$AppName successfully installed."
            } else {
                Write-Host "Failed to install $AppName via Chocolatey."
            }
        } catch {
            Write-Host "Failed to install $AppName via Chocolatey. Error: $_"
        }
    }
}

# Ophalen JSON vanaf het opgegeven lokale bestand
try {
    $jsonContent = Get-Content -Path $JsonFilePath -Raw
    $applications = (ConvertFrom-Json -InputObject $jsonContent)
} catch {
    Write-Host "Failed to read or parse JSON file. Error: $_"
    exit 1
}

# Doorlopen van de applicaties en installeren
foreach ($app in $applications) {
    Install-ChocoApp -AppName $app
}


