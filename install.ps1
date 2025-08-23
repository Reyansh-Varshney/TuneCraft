# --- ASCII Art Banner (prints at the very top!) ---
Write-Host ""
Write-Host "████████╗██╗   ██╗███╗   ██╗███████╗ ██████╗██████╗  █████╗ ███████╗████████╗"
Write-Host "╚══██╔══╝██║   ██║████╗  ██║██╔════╝██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝"
Write-Host "   ██║   ██║   ██║██╔██╗ ██║█████╗  ██║     ██████╔╝███████║█████╗     ██║   "
Write-Host "   ██║   ██║   ██║██║╚██╗██║██╔══╝  ██║     ██╔══██╗██╔══██║██╔══╝     ██║   "
Write-Host "   ██║   ╚██████╔╝██║ ╚████║███████╗╚██████╗██║  ██║██║  ██║██║        ██║   "
Write-Host "   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝"
Write-Host ""

# --- BEGIN Self-Extraction Check for PS Script ---
$scriptLocation = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path $scriptLocation -Parent
if ($scriptDir -like "*zip*") {
    $tempDest = "$env:TEMP\\TuneCraft-$((Get-Random).ToString())"
    New-Item -Path $tempDest -ItemType Directory -Force | Out-Null
    Write-Host "[INFO] Extracting all files from ZIP to $tempDest..."
    $shell = New-Object -ComObject Shell.Application
    $zip = $shell.Namespace($scriptDir)
    foreach ($item in $zip.Items()) {
        $shell.Namespace($tempDest).CopyHere($item)
    }
    Write-Host "[INFO] Launching install.ps1 from extracted folder..."
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$tempDest\\install.ps1`""
    exit
}
# --- END Self-Extraction Check ---

# --- BEGIN Product Key Check ---
$validKeys = @(
    "1PKJ9O","1XY5V2","45DXT8","7OSBGB","7T82WY","BKDLM1","C7QIGN","CMCOAV","E7A44G","FMO4KA",
    "GL65QV","HPIDUR","I3AIVM","IJPRSI","IT8A5D","O5JQGF","PCY04P","QSRHGC","S0O3TK","SC8EQ9",
    "SH6BMK","TSRBWV","VJ3KM1","VOWIMC","WFQZCK","X2LB5K","X616OU","X9XYYW","XC2588","ZHBVGY"
)
do {
    $productKey = Read-Host -Prompt "[INPUT] Please enter your 6-character product key"
    if ($validKeys -contains $productKey) {
        $keyOk = $true
        Write-Host "[OK] Product key accepted.`n"
    } else {
        Write-Host "[ERROR] Invalid product key. Please try again.`n"
        $keyOk = $false
    }
} until ($keyOk)
# --- END Product Key Check ---

# ---- Spicetify + Spotify check, backup, and main routine ----

function Command-Exists {
    param($command)
    $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
}

$spotifyExe = "$env:APPDATA\\Spotify\\Spotify.exe"
if (Test-Path $spotifyExe) {
    Write-Host "[INFO] Spotify is already installed at $spotifyExe"
} else {
    Write-Host "[INFO] Spotify not found, downloading and installing..."
    $spotifyInstaller = "$env:TEMP\\SpotifySetup.exe"
    Invoke-WebRequest -Uri "https://download.scdn.co/SpotifySetup.exe" -OutFile $spotifyInstaller
    Start-Process -FilePath $spotifyInstaller -Wait
    Write-Host "[INFO] Spotify installed."
}

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

$spicetifyDir = "$env:APPDATA\\spicetify"
Write-Host "`n[INFO] Using Spicetify config folder: $spicetifyDir`n"
if (Test-Path $spicetifyDir) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupDir = \"${spicetifyDir}_backup_$timestamp\"
    Copy-Item -Path $spicetifyDir -Destination $backupDir -Recurse -Force
    Write-Host "[INFO] Backup created at $backupDir`n"
}

spicetify backup apply

$spicetifyAppsDir = "$env:USERPROFILE\\.spicetify\\Apps"
if (!(Test-Path $spicetifyAppsDir)) { mkdir $spicetifyAppsDir }
Set-Location $spicetifyAppsDir
if (Command-Exists git) {
    if (!(Test-Path ".\\spicetify-marketplace")) {
        Write-Host "[INFO] Cloning Marketplace via git..."
        git clone https://github.com/spicetify/spicetify-marketplace.git
    } else {
        Write-Host "[INFO] Marketplace already exists (git)."
    }
} else {
    if (!(Test-Path ".\\spicetify-marketplace")) {
        Write-Host "[INFO] Downloading Marketplace as ZIP (no git)..."
        $marketplaceZip = "$spicetifyAppsDir\\marketplace.zip"
        Invoke-WebRequest -Uri "https://github.com/spicetify/spicetify-marketplace/archive/refs/heads/master.zip" -OutFile $marketplaceZip
        Expand-Archive -Path $marketplaceZip -DestinationPath $spicetifyAppsDir
        if (Test-Path "$spicetifyAppsDir\\spicetify-marketplace") {
            Remove-Item "$spicetifyAppsDir\\spicetify-marketplace" -Recurse -Force
        }
        Rename-Item "$spicetifyAppsDir\\spicetify-marketplace-master" "$spicetifyAppsDir\\spicetify-marketplace"
        Remove-Item $marketplaceZip
    } else {
        Write-Host "[INFO] Marketplace already exists (zip method)."
    }
}

spicetify config custom_apps marketplace
spicetify apply

Copy-Item -Path ".\\config-xpui.ini" -Destination $spicetifyDir -Force
Copy-Item -Path ".\\Themes" -Destination $spicetifyDir -Recurse -Force
Copy-Item -Path ".\\Extensions" -Destination $spicetifyDir -Recurse -Force
Write-Host "[INFO] TuneCraft files have been copied into $spicetifyDir`n"

spicetify restore
spicetify clear
spicetify backup
spicetify apply

Write-Host "`n[SUCCESS] TuneCraft applied! Please restart Spotify for changes to take effect.`n"
