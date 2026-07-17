#!/bin/bash
#
# Description: Installs Google Chrome on macOS via the official Google DMG.
#              Downloads the universal stable DMG, mounts it, locates the .app
#              bundle inside, and copies it to /Applications. Cleans up the
#              temp download and unmounts the DMG when done.
#
# Configurable variables (edit at the top of the script or pass via RMM):
#   DownloadUrl     - Direct URL to the Chrome DMG (default: Google stable universal)
#   ForceReinstall  - Set to "True" to remove and reinstall if Chrome is already present
#
# Exit codes:
#   0 - Chrome installed successfully (or already present and ForceReinstall=False)
#   1 - Fatal error (download failure, mount failure, copy failure, etc.)
#
# Tested on: macOS (Apple Silicon + Intel via universal binary)
# Requires:  curl, hdiutil (both available by default on macOS)

DownloadUrl="https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg"
ForceReinstall="False"   # Set to "True" to reinstall even if already present

# ── Logging ──────────────────────────────────────────────────
log()  { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*"; }

abort() {
    echo "[ERROR] $*"
    [[ -n "$DMGMountPoint" ]] && { hdiutil detach "$DMGMountPoint" -quiet 2>/dev/null; log "Detached DMG volume"; }
    [[ -d "$TempFolder" ]]    && { rm -rf "$TempFolder"; log "Cleaned up $TempFolder"; }
    exit 1
}

# ── Download ──────────────────────────────────────────────────
TempFolder=$(mktemp -d) || abort "Failed to create temp folder"
log "Temp folder created: $TempFolder"

log "Downloading Google Chrome DMG..."
curl -sL "$DownloadUrl" -o "$TempFolder/GoogleChrome.dmg" || abort "Download failed"
log "Download complete"

# ── Mount DMG ─────────────────────────────────────────────────
log "Mounting DMG..."
hdiutilOutput=$(hdiutil attach "$TempFolder/GoogleChrome.dmg" -nobrowse 2>&1)
[[ $? -ne 0 ]] && abort "hdiutil attach failed: $hdiutilOutput"

DMGVolume=$(echo "$hdiutilOutput" | grep '/Volumes/' | awk -F'\t' '{print $NF}' | tail -1 | sed 's/[[:space:]]*$//')
[[ -d "$DMGVolume" ]] || abort "Could not locate mounted DMG volume. hdiutil output: $hdiutilOutput"
log "Mounted volume: $DMGVolume"

DMGMountPoint=$(echo "$hdiutilOutput" | grep '/Volumes/' | awk -F'\t' '{print $1}' | tail -1 | sed 's/[[:space:]]*$//')
log "Mount point: $DMGMountPoint"

# ── Find .app inside DMG ──────────────────────────────────────
DMGAppPath=$(find "$DMGVolume" -maxdepth 1 -name "*.app" | head -1)
[[ -n "$DMGAppPath" ]] || abort "No .app bundle found in $DMGVolume"
AppName=$(basename "$DMGAppPath")
log "Found app: $AppName"

# ── Check for existing install ────────────────────────────────
if [[ -d "/Applications/$AppName" ]]; then
    if [[ "$ForceReinstall" == "True" ]]; then
        warn "$AppName already installed — removing for reinstall"
        rm -rf "/Applications/$AppName" || abort "Could not remove existing $AppName"
    else
        warn "$AppName is already installed. Set ForceReinstall=True to reinstall."
        hdiutil detach "$DMGMountPoint" -quiet
        rm -rf "$TempFolder"
        exit 0
    fi
fi

# ── Install ───────────────────────────────────────────────────
log "Installing $AppName to /Applications..."
cp -pPR "$DMGAppPath" /Applications/ || abort "Failed to copy $AppName to /Applications"
log "Google Chrome installed successfully"

# ── Cleanup ───────────────────────────────────────────────────
hdiutil detach "$DMGMountPoint" -quiet
log "Detached DMG volume"
rm -rf "$TempFolder"
log "Cleaned up temp folder"

log "Installation complete."
exit 0