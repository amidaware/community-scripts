#!/usr/bin/env bash
###############################################################################
# Script Name : linux_disk_usage.sh
# Description : Used to check the disk usage of mounted Linux filesystems and
#               return an alert if usage exceeds the specified thresholds.
#               (Default warning threshold is 75% and default error threshold
#               is 90%; thresholds can be changed via -w/--warning and -e/--error
#               flags or the WARNINGVALUE and ERRORVALUE environment variables.)
#
# Exit Codes  :
#   0 - OK       (No thresholds exceeded)
#   1 - Invalid input / script failure
#   2 - WARNING  (Warning threshold exceeded)
#   3 - ERROR    (Error threshold exceeded)
#
# Parameters  :
#   -w, --warning <int>  Warning threshold percentage (default: 75)
#   -e, --error   <int>  Error threshold percentage   (default: 90)
#
# Environment :
#   WARNINGVALUE  Alternative warning threshold
#   ERRORVALUE    Alternative error threshold
#
# Examples    :
#   ./linux_disk_usage.sh -w 70 -e 85
#   WARNINGVALUE=70 ERRORVALUE=85 ./linux_disk_usage.sh
#
# Compatibility:
#   Linux (GNU coreutils)
#
# Repository  : https://github.com/amidaware/community-scripts
# Category    : TRMM (nix):System Monitoring
# Version     : 1.0
# Last Updated: 2026-02-06
###############################################################################

# ------------------------------- Defaults ---------------------------------- #
WARNINGVALUE="${WARNINGVALUE:-75}"
ERRORVALUE="${ERRORVALUE:-90}"

# Filesystems to exclude (regex)
EXCLUDE_FS_REGEX='^(tmpfs|devtmpfs|overlay|squashfs|ramfs|/dev/loop)'

# ----------------------------- Arg Parsing --------------------------------- #
while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--warning)
            WARNINGVALUE="$2"
            shift 2
            ;;
        -e|--error)
            ERRORVALUE="$2"
            shift 2
            ;;
        *)
            echo "ERROR: Unknown argument: $1"
            exit 1
            ;;
    esac
done

# ---------------------------- Validation ----------------------------------- #
for val in "$WARNINGVALUE" "$ERRORVALUE"; do
    if ! [[ "$val" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Threshold values must be integers"
        exit 1
    fi
done

if (( WARNINGVALUE >= ERRORVALUE )); then
    echo "ERROR: Warning threshold must be less than error threshold"
    exit 1
fi

command -v df >/dev/null 2>&1 || {
    echo "ERROR: Required command 'df' not found"
    exit 1
}

# ----------------------------- Execution ----------------------------------- #
result=0

while IFS='|' read -r filesystem mountpoint used size usage; do
    usage="${usage%\%}"

    if (( usage >= ERRORVALUE )); then
        echo "ERROR: $filesystem mounted on $mountpoint is ${usage}% used (${used}/${size}) (>= ${ERRORVALUE}%)"
        result=3
    elif (( usage >= WARNINGVALUE )); then
        [[ $result -lt 2 ]] && result=2
        echo "WARNING: $filesystem mounted on $mountpoint is ${usage}% used (${used}/${size}) (>= ${WARNINGVALUE}%)"
    else
        echo "OK: $filesystem mounted on $mountpoint is ${usage}% used (${used}/${size})"
    fi
done < <(
    df --output=source,fstype,target,used,size,pcent -h \
    | tail -n +2 \
    | awk -v exclude="$EXCLUDE_FS_REGEX" '
        $1 ~ /^\/dev\// &&
        $2 !~ exclude {
            print $1 "|" $3 "|" $4 "|" $5 "|" $6
        }
    '
)

exit "$result"
