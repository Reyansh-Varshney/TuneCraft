Write-Host ""
Write-Host "████████╗██╗   ██╗███╗   ██╗███████╗ ██████╗██████╗  █████╗ ███████╗████████╗"
Write-Host "╚══██╔══╝██║   ██║████╗  ██║██╔════╝██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝"
Write-Host "   ██║   ██║   ██║██╔██╗ ██║█████╗  ██║     ██████╔╝███████║█████╗     ██║   "
Write-Host "   ██║   ██║   ██║██║╚██╗██║██╔══╝  ██║     ██╔══██╗██╔══██║██╔══╝     ██║   "
Write-Host "   ██║   ╚██████╔╝██║ ╚████║███████╗╚██████╗██║  ██║██║  ██║██║        ██║   "
Write-Host "   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝"
Write-Host ""

$spicetifyDir = "$env:APPDATA\spicetify"
Write-Host "`n[INFO] Using Spicetify config folder: $spicetifyDir`n"

if (Test-Path $spicetifyDir) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupDir = "${spicetifyDir}_backup_$timestamp"
    Copy-Item -Path $spicetifyDir -Destination $backupDir -Recurse -Force
    Write-Host "[INFO] Backup created at $backupDir`n"
}

Copy-Item -Path ".\config-xpui.ini" -Destination $spicetifyDir -Force
Copy-Item -Path ".\Themes" -Destination $spicetifyDir -Recurse -Force
Copy-Item -Path ".\Extensions" -Destination $spicetifyDir -Recurse -Force
Write-Host "[INFO] TuneCraft files have been copied into $spicetifyDir`n"

spicetify restore
spicetify clear
spicetify backup
spicetify apply

Write-Host "`n[SUCCESS] TuneCraft applied! Please restart Spotify for changes to take effect.`n"
