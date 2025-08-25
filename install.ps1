# TuneCraft Installer – Product Key, Spotify/Spicetify Auto-Installer, One-Time, Smart Copy-All Except Self

Write-Host ""
Write-Host "████████╗██╗   ██╗███╗   ██╗███████╗ ██████╗██████╗  █████╗ ███████╗████████╗"
Write-Host "╚══██╔══╝██║   ██║████╗  ██║██╔════╝██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝"
Write-Host "   ██║   ██║   ██║██╔██╗ ██║█████╗  ██║     ██████╔╝███████║█████╗     ██║   "
Write-Host "   ██║   ██║   ██║██║╚██╗██║██╔══╝  ██║     ██╔══██╗██╔══██║██╔══╝     ██║   "
Write-Host "   ██║   ╚██████╔╝██║ ╚████║███████╗╚██████╗██║  ██║██║  ██║██║        ██║   "
Write-Host "   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝"
Write-Host ""

function Get-SHA256Hash([string]$text) {
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $hash = $sha256.ComputeHash($bytes)
    -join ($hash | ForEach-Object { "{0:x2}" -f $_ })
}

# --- 1. PRODUCT KEY CHECK (don't burn yet!)
Write-Host "`nENTER YOUR TUNECRAFT PRODUCT KEY (format: TC-2025-XXXX-YYYY):"
$userKey = Read-Host
$userHash = Get-SHA256Hash $userKey
$firebaseBase = "https://tunecrafters2025-default-rtdb.asia-southeast1.firebasedatabase.app/keys"
$firebaseUrl = "$firebaseBase/$userHash.json"
try {
    $response = Invoke-WebRequest -Uri $firebaseUrl -UseBasicParsing -ErrorAction Stop
    $keyInfo = $response.Content | ConvertFrom-Json
} catch {
    Write-Host "`n[ERROR] Unable to contact license server. Check your internet connection." -ForegroundColor Red
    exit 1
}
if ($null -eq $keyInfo -or $keyInfo.used) {
    Write-Host "`n[ERROR] Product key invalid or already used. Exiting!" -ForegroundColor Red
    exit 1
}
Write-Host "`n[OK] Product key accepted. Proceeding with installation..." -ForegroundColor Green

$installSuccess = $true
try {
    # ---- SPOTIFY: Check/install if missing ----
    function Is-SpotifyInstalled {
        $spotify = Get-ChildItem "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall" | Where-Object {
            $_.GetValue("DisplayName") -like "*Spotify*"
        }
        return $null -ne $spotify
    }
    if (-not (Is-SpotifyInstalled)) {
        Write-Host "`n[INFO] Spotify not found - downloading and installing latest version..." -ForegroundColor Yellow
        $spotifyInstallerUrl = "https://download.scdn.co/SpotifySetup.exe"
        $spotifyLocal = "$env:TEMP\\SpotifySetup.exe"
        Invoke-WebRequest -Uri $spotifyInstallerUrl -OutFile $spotifyLocal -UseBasicParsing
        Start-Process -FilePath $spotifyLocal -Wait
        Write-Host "[INFO] Please finish Spotify install, then press ENTER to continue once complete."
        Read-Host
    } else {
        Write-Host "`n[INFO] Spotify already installed."
    }

    # ---- SPICETIFY: Install if missing ----
    function Is-SpicetifyInstalled {
        $exists = Get-Command spicetify -ErrorAction SilentlyContinue
        return $null -ne $exists
    }
    if (-not (Is-SpicetifyInstalled)) {
        Write-Host "`n[INFO] Spicetify CLI not found - installing via official script..." -ForegroundColor Yellow
        iwr -useb https://raw.githubusercontent.com/spicetify/cli/main/install.ps1 | iex
        Write-Host "[INFO] Spicetify CLI is now installed. Make sure spicetify.exe is in your PATH."
    } else {
        Write-Host "`n[INFO] Spicetify CLI already installed."
    }

    # ---- ENSURE %APPDATA%\spicetify EXISTS ----
    $spicetifyDir = Join-Path $env:APPDATA "spicetify"
    if (!(Test-Path $spicetifyDir)) {
        New-Item -ItemType Directory -Path $spicetifyDir -Force | Out-Null
        Write-Host "[INFO] Created $spicetifyDir"
    } else {
        Write-Host "[INFO] Using Spicetify config folder: $spicetifyDir"
    }

    # ---- COPY EVERYTHING EXCEPT THE INSTALLER ITSELF ----
    $sourcePath = Get-Location
    $installerScriptName = $MyInvocation.MyCommand.Name
    Get-ChildItem -Path $sourcePath -Exclude $installerScriptName | ForEach-Object {
        $target = Join-Path $spicetifyDir $_.Name
        # Remove existing (file or folder) if it already exists
        if (Test-Path $target) {
            Remove-Item -Path $target -Recurse -Force
        }
        Copy-Item -Path $_.FullName -Destination $spicetifyDir -Recurse -Force
    }
    Write-Host "[INFO] All TuneCraft files (including Themes, Extensions, CustomApps, etc) copied into $spicetifyDir`n"

    # ---- COMMAND SEQUENCE (using your config-xpui.ini) ----
    $mainConfig = ".\config-xpui.ini"
    spicetify restore
    spicetify clear
    spicetify backup
    # Copy config after backup (in case Spicetify restores default)
    Copy-Item $mainConfig $spicetifyDir -Force
    spicetify apply

    Write-Host "`n[SUCCESS] TuneCraft applied! Please restart Spotify for changes to take effect.`n"
}
catch {
    $installSuccess = $false
    Write-Host "`n[ERROR] TuneCraft installation failed. Product key NOT burned – you may retry." -ForegroundColor Red
    exit 1
}

# --- Step 3: ONLY "BURN" THE KEY IF FULL INSTALL SUCCEEDED ---
if ($installSuccess) {
    $payload = @{ used = $true } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri $firebaseUrl -Method Put -Body $payload -ContentType "application/json" -ErrorAction Stop
        Write-Host "`n[SUCCESS] Your key was accepted and is now burned. TuneCraft is successfully installed!" -ForegroundColor Green
    } catch {
        Write-Host "`n[WARNING] TuneCraft installed, but failed to update license server. Please contact support with your key!" -ForegroundColor Yellow
    }
}
