# ASCII Art Banner
Write-Host ""
Write-Host "████████╗██╗   ██╗███╗   ██╗███████╗ ██████╗██████╗  █████╗ ███████╗████████╗"
Write-Host "╚══██╔══╝██║   ██║████╗  ██║██╔════╝██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝"
Write-Host "   ██║   ██║   ██║██╔██╗ ██║█████╗  ██║     ██████╔╝███████║█████╗     ██║   "
Write-Host "   ██║   ██║   ██║██║╚██╗██║██╔══╝  ██║     ██╔══██╗██╔══██║██╔══╝     ██║   "
Write-Host "   ██║   ╚██████╔╝██║ ╚████║███████╗╚██████╗██║  ██║██║  ██║██║        ██║   "
Write-Host "   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝"
Write-Host ""

# Helper: Command Exists
function Command-Exists {
    param($command)
    $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
}

# Step 1: Check Spotify installation (by default path)
$spotifyExe = "$env:APPDATA\Spotify\Spotify.exe"
if (Test-Path $spotifyExe) {
    Write-Host "[INFO] Spotify is already installed at $spotifyExe"
} else {
    Write-Host "[INFO] Spotify not found, downloading and installing..."
    $spotifyInstaller = "$env:TEMP\SpotifySetup.exe"
    Invoke-WebRequest -Uri "https://download.scdn.co/SpotifySetup.exe" -OutFile $spotifyInstaller
    Start-Process -FilePath $spotifyInstaller -Wait
    Write-Host "[INFO] Spotify installed."
}

# Step 2: Check Spicetify CLI
if (Command-Exists spicetify) {
    Write-Host "[INFO] Spicetify CLI is already installed."
} elseif (Command-Exists winget) {
    Write-Host "[INFO] Spicetify not found. Installing with winget..."
    winget install --id=spicetify.cli -e --source=winget
    Write-Host "[INFO] Spicetify installed."
} else {
    Write-Host "[ERROR] Spicetify CLI is not installed and winget is unavailable. Please install manually and re-run."
    exit
}

# Spicetify config and backup
$spicetifyDir = "$env:APPDATA\spicetify"
Write-Host "`n[INFO] Using Spicetify config folder: $spicetifyDir`n"
if (Test-Path $spicetifyDir) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupDir = "${spicetifyDir}_backup_$timestamp"
    Copy-Item -Path $spicetifyDir -Destination $backupDir -Recurse -Force
    Write-Host "[INFO] Backup created at $backupDir`n"
}

# Step 3: spicetify backup/apply to initialize configs if first run
spicetify backup apply

# Step 4: Install Marketplace custom app (via git if available, else ZIP)
$spicetifyAppsDir = "$env:USERPROFILE\.spicetify\Apps"
if (!(Test-Path $spicetifyAppsDir)) { mkdir $spicetifyAppsDir }
Set-Location $spicetifyAppsDir

if (Command-Exists git) {
    if (!(Test-Path ".\spicetify-marketplace")) {
        Write-Host "[INFO] Cloning Marketplace via git..."
        git clone https://github.com/spicetify/spicetify-marketplace.git
    } else {
        Write-Host "[INFO] Marketplace already exists (git)."
    }
} else {
    if (!(Test-Path ".\spicetify-marketplace")) {
        Write-Host "[INFO] Downloading Marketplace as ZIP (no git)..."
        $marketplaceZip = "$spicetifyAppsDir\marketplace.zip"
        Invoke-WebRequest -Uri "https://github.com/spicetify/spicetify-marketplace/archive/refs/heads/master.zip" -OutFile $marketplaceZip
        Expand-Archive -Path $marketplaceZip -DestinationPath $spicetifyAppsDir
        if (Test-Path "$spicetifyAppsDir\spicetify-marketplace") {
            Remove-Item "$spicetifyAppsDir\spicetify-marketplace" -Recurse -Force
        }
        Rename-Item "$spicetifyAppsDir\spicetify-marketplace-master" "$spicetifyAppsDir\spicetify-marketplace"
        Remove-Item $marketplaceZip
    } else {
        Write-Host "[INFO] Marketplace already exists (zip method)."
    }
}

# Step 5: Enable marketplace and apply
spicetify config custom_apps marketplace
spicetify apply

# TuneCraft copy operations
Copy-Item -Path ".\config-xpui.ini" -Destination $spicetifyDir -Force
Copy-Item -Path ".\Themes" -Destination $spicetifyDir -Recurse -Force
Copy-Item -Path ".\Extensions" -Destination $spicetifyDir -Recurse -Force
Write-Host "[INFO] TuneCraft files have been copied into $spicetifyDir`n"

# Spicetify commands for TuneCraft
spicetify restore
spicetify clear
spicetify backup
spicetify apply

Write-Host "`n[SUCCESS] TuneCraft applied! Please restart Spotify for changes to take effect.`n"
