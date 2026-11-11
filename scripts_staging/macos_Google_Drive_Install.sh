#!/bin/bash
#
# Description: Installs Google Drive on macOS via the official Google DMG.
#              Downloads the DMG, mounts it, locates the PKG installer inside,
#              and runs it against the system target. Unlike a direct .app copy,
#              this uses macOS's `installer` command to handle the PKG payload,
#              which registers Google Drive's system components properly.
#              Cleans up the temp download and unmounts the DMG when done.
#
# Configurable variables (edit at the top of the script or pass via RMM):
#   DownloadUrl     - Direct URL to the Google Drive DMG (default: Google stable)
#   ForceReinstall  - Set to "True" to proceed with install even if already present
#   AppName         - Expected app name used to detect an existing installation
#   InstallPath     - Parent directory checked for an existing install (default: /Applications)
#
# Exit codes:
#   0 - Google Drive installed successfully (or already present and ForceReinstall=False)
#   1 - Fatal error (download failure, mount failure, PKG install failure, etc.)
#
# Tested on: macOS (Apple Silicon + Intel)
# Requires:  curl, hdiutil, installer (all available by default on macOS)

DownloadUrl="https://dl.google.com/drive-file-stream/GoogleDrive.dmg"
ForceReinstall="False"   # Set to "True" to reinstall even if already present
AppName="Google Drive.app"
InstallPath="/Applications"

# ── Logging ──────────────────────────────────────────────────
log()  { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*"; }

abort() {
    echo "[ERROR] $*"
    [[ -n "$DMGMountPoint" ]] && { hdiutil detach "$DMGMountPoint" -quiet 2>/dev/null; log "Detached DMG volume"; }
    [[ -d "$TempFolder" ]]    && { rm -rf "$TempFolder"; log "Cleaned up $TempFolder"; }
    exit 1
}

# ── Existing install check ────────────────────────────────────
if [[ -d "$InstallPath/$AppName" ]]; then
    if [[ "$ForceReinstall" != "True" ]]; then
        log "Google Drive is already installed. Set ForceReinstall=True to reinstall."
        exit 0
    else
        warn "ForceReinstall=True — proceeding with reinstall"
    fi
fi

# ── Download ──────────────────────────────────────────────────
TempFolder=$(mktemp -d) || abort "Failed to create temp folder"
log "Temp folder created: $TempFolder"

log "Downloading Google Drive DMG..."
curl -sL "$DownloadUrl" -o "$TempFolder/GoogleDrive.dmg" || abort "Download failed"
log "Download complete"

# ── Mount DMG ─────────────────────────────────────────────────
log "Mounting DMG..."
hdiutilOutput=$(hdiutil attach "$TempFolder/GoogleDrive.dmg" -nobrowse 2>&1)
[[ $? -ne 0 ]] && abort "hdiutil attach failed: $hdiutilOutput"

DMGVolume=$(echo "$hdiutilOutput" | grep '/Volumes/' | awk -F'\t' '{print $NF}' | tail -1 | sed 's/[[:space:]]*$//')
[[ -d "$DMGVolume" ]] || abort "Could not locate mounted DMG volume. hdiutil output: $hdiutilOutput"
log "Mounted volume: $DMGVolume"

DMGMountPoint=$(echo "$hdiutilOutput" | grep '/Volumes/' | awk -F'\t' '{print $1}' | tail -1 | sed 's/[[:space:]]*$//')
log "Mount point: $DMGMountPoint"

# ── Find PKG inside DMG ───────────────────────────────────────
DMGPkgPath=$(find "$DMGVolume" -maxdepth 1 -name "*.pkg" | head -1)
[[ -n "$DMGPkgPath" ]] || abort "No PKG found inside $DMGVolume"
log "Found PKG: $DMGPkgPath"

# ── Install PKG ───────────────────────────────────────────────
log "Installing Google Drive..."
installer -pkg "$DMGPkgPath" -target / -verboseR
[[ $? -ne 0 ]] && abort "PKG installation failed"
log "Google Drive installed successfully"

# ── Cleanup ───────────────────────────────────────────────────
hdiutil detach "$DMGMountPoint" -quiet
log "Detached DMG volume"
rm -rf "$TempFolder"
log "Cleaned up temp folder"

log "Installation complete."
exit 0