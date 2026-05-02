#!/bin/bash
#
# Description: Installs Visual Studio Code on macOS via the official Microsoft DMG.
#              Automatically selects the correct DMG for the machine's CPU architecture:
#              ARM64 (Apple Silicon), x86_64 (Intel), or universal as a fallback.
#              The download URL is a redirect link; the script follows HTTP redirects
#              to resolve the final DMG location before downloading. Once downloaded,
#              it mounts the DMG, locates the .app bundle inside, and copies it to
#              /Applications. Cleans up the temp download and unmounts the DMG when done.
#
# Configurable variables (edit at the top of the script or pass via RMM):
#   ForceReinstall  - Set to "True" to remove and reinstall if VS Code is already present
#
# Exit codes:
#   0 - VS Code installed successfully (or already present and ForceReinstall=False)
#   1 - Fatal error (URL resolution failure, download failure, mount failure, copy failure, etc.)
#
# Tested on: macOS Apple Silicon (ARM64) and Intel (x86_64)
# Requires:  curl, hdiutil, uname (all available by default on macOS)

ForceReinstall="False"   # Set to "True" to reinstall even if already present

# ── Logging ──────────────────────────────────────────────────
log()  { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*"; }

# ── Select architecture-appropriate download URL ──────────────
Arch=$(uname -m)
case "$Arch" in
    arm64)
        DownloadUrl="https://code.visualstudio.com/sha/download?build=stable&os=darwin-arm64-dmg"
        log "Detected Apple Silicon (arm64)"
        ;;
    x86_64)
        DownloadUrl="https://code.visualstudio.com/sha/download?build=stable&os=darwin-x64-dmg"
        log "Detected Intel (x86_64)"
        ;;
    *)
        DownloadUrl="https://code.visualstudio.com/sha/download?build=stable&os=darwin-universal-dmg"
        warn "Unknown architecture '$Arch' — falling back to universal DMG"
        ;;
esac

abort() {
    echo "[ERROR] $*"
    [[ -n "$DMGMountPoint" ]] && { hdiutil detach "$DMGMountPoint" -quiet 2>/dev/null; log "Detached DMG volume"; }
    [[ -d "$TempFolder" ]]    && { rm -rf "$TempFolder"; log "Cleaned up $TempFolder"; }
    exit 1
}

# ── Resolve Final Download URL ────────────────────────────────
log "Resolving download URL: $DownloadUrl"
if [[ "$DownloadUrl" == *".dmg"* ]]; then
    log "Direct download link detected"
    ResolvedUrl="$DownloadUrl"
else
    log "Following redirects to find final DMG URL..."
    ResolvedUrl=$(curl -sIL "$DownloadUrl" | grep -i "^location:" | tail -1 | awk '{print $2}' | tr -d '[:space:]')
    [[ "$ResolvedUrl" == *".dmg"* ]] || abort "Could not resolve a .dmg URL from headers. Got: $ResolvedUrl"
    log "Resolved URL: $ResolvedUrl"
fi

# ── Download ──────────────────────────────────────────────────
TempFolder=$(mktemp -d) || abort "Failed to create temp folder"
log "Temp folder created: $TempFolder"

log "Downloading Visual Studio Code DMG..."
curl -sL "$ResolvedUrl" -o "$TempFolder/VSCode.dmg" || abort "Download failed"
log "Download complete"

# ── Mount DMG ─────────────────────────────────────────────────
log "Mounting DMG..."
hdiutilOutput=$(hdiutil attach "$TempFolder/VSCode.dmg" -nobrowse 2>&1)
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
log "Visual Studio Code installed successfully"

# ── Cleanup ───────────────────────────────────────────────────
hdiutil detach "$DMGMountPoint" -quiet
log "Detached DMG volume"
rm -rf "$TempFolder"
log "Cleaned up temp folder"

log "Installation complete."
exit 0