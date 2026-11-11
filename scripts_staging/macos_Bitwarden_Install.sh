#!/bin/bash
#
# Description: Installs Bitwarden on macOS via the official Bitwarden DMG.
#              The download URL redirects through Bitwarden's vault CDN and resolves
#              to a DMG whose final URL contains a query string after the .dmg extension;
#              the script follows HTTP redirects and checks for ".dmg" anywhere in the
#              resolved URL (not just at the end) to handle this quirk. Once downloaded,
#              it mounts the DMG, locates the .app bundle inside, and copies it to
#              /Applications. Cleans up the temp download and unmounts the DMG when done.
#
# Configurable variables (edit at the top of the script or pass via RMM):
#   DownloadUrl     - URL to the Bitwarden DMG redirect (default: official macOS desktop build)
#   ForceReinstall  - Set to "True" to remove and reinstall if Bitwarden is already present
#
# Exit codes:
#   0 - Bitwarden installed successfully (or already present and ForceReinstall=False)
#   1 - Fatal error (URL resolution failure, download failure, mount failure, copy failure, etc.)
#
# Tested on: macOS (universal binary — works on Apple Silicon and Intel)
# Requires:  curl, hdiutil (both available by default on macOS)

DownloadUrl="https://vault.bitwarden.com/download/?app=desktop&platform=macos&variant=dmg"
ForceReinstall="False"   # Set to "True" to reinstall even if already present
# ============================================================

# ── Logging ──────────────────────────────────────────────────
log()  { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*"; }

abort() {
    echo "[ERROR] $*"
    [[ -n "$DMGMountPoint" ]] && { hdiutil detach "$DMGMountPoint" -quiet 2>/dev/null; log "Detached DMG volume"; }
    [[ -d "$TempFolder" ]]    && { rm -rf "$TempFolder"; log "Cleaned up $TempFolder"; }
    exit 1
}

# ── Resolve Final Download URL ────────────────────────────────
log "Resolving download URL: $DownloadUrl"
ResolvedUrl=$(curl -sIL "$DownloadUrl" | grep -i "^location:" | tail -1 | awk '{print $2}' | tr -d '[:space:]')

# Check if .dmg appears anywhere in the URL (may have query string after extension)
[[ "$ResolvedUrl" == *".dmg"* ]] || abort "Could not resolve a .dmg URL from headers. Got: $ResolvedUrl"
log "Resolved URL: $ResolvedUrl"

# ── Download ──────────────────────────────────────────────────
TempFolder=$(mktemp -d) || abort "Failed to create temp folder"
log "Temp folder created: $TempFolder"

log "Downloading Bitwarden DMG..."
curl -sL "$ResolvedUrl" -o "$TempFolder/Bitwarden.dmg" || abort "Download failed"
log "Download complete"

# ── Mount DMG ─────────────────────────────────────────────────
log "Mounting DMG..."
hdiutilOutput=$(hdiutil attach "$TempFolder/Bitwarden.dmg" -nobrowse 2>&1)
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
log "Bitwarden installed successfully"

# ── Cleanup ───────────────────────────────────────────────────
hdiutil detach "$DMGMountPoint" -quiet
log "Detached DMG volume"
rm -rf "$TempFolder"
log "Cleaned up temp folder"

log "Installation complete."
exit 0