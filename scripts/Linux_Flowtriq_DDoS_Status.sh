#!/usr/bin/env bash
#
# Flowtriq ftagent DDoS Status Check
#
# Queries the local ftagent health endpoint (default: 127.0.0.1:9100) and
# reports current DDoS attack status to TacticalRMM.
#
# Exit codes:
#   0 - Agent healthy, no attack in progress
#   1 - Attack active OR agent unreachable (alert)
#
# Arguments (key=value format):
#   port=9100       ftagent health port (default: 9100)
#   timeout=5       HTTP request timeout in seconds (default: 5)
#   warn_no_baseline=1   Alert if baseline not yet ready (default: 0)
#
# Example:
#   Run as: Linux_Flowtriq_DDoS_Status.sh port=9100 warn_no_baseline=1

for ARGUMENT in "$@"; do
    KEY=$(echo "$ARGUMENT" | cut -f1 -d=)
    KEY_LENGTH=${#KEY}
    VALUE="${ARGUMENT:$KEY_LENGTH+1}"
    export "$KEY"="$VALUE"
done

# Defaults
port="${port:-9100}"
timeout="${timeout:-5}"
warn_no_baseline="${warn_no_baseline:-0}"

ENDPOINT="http://127.0.0.1:${port}/"

# Require curl
if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is not installed. Install curl and retry."
    exit 1
fi

# Query health endpoint
RESPONSE=$(curl -sf --max-time "${timeout}" "${ENDPOINT}" 2>&1)
CURL_EXIT=$?

if [ $CURL_EXIT -ne 0 ]; then
    echo "CRITICAL: ftagent health endpoint unreachable at ${ENDPOINT} (curl exit ${CURL_EXIT})"
    echo "Ensure ftagent is running: systemctl status ftagent"
    exit 1
fi

# Parse JSON fields using basic shell tools (no jq dependency)
_json_field() {
    local field="$1"
    echo "$RESPONSE" | grep -o "\"${field}\":[^,}]*" | head -1 | sed 's/.*://' | tr -d '"' | tr -d ' '
}

STATUS=$(       _json_field "status")
ATTACK_ACTIVE=$(  _json_field "attack_active")
INCIDENT_UUID=$(  _json_field "incident_uuid")
CURRENT_PPS=$(    _json_field "current_pps")
CURRENT_BPS=$(    _json_field "current_bps")
BASELINE_READY=$( _json_field "baseline_ready")
VERSION=$(        _json_field "version")
UPTIME=$(         _json_field "uptime_seconds")
INTERFACE=$(      _json_field "interface")

# Validate we got a response
if [ -z "$STATUS" ]; then
    echo "CRITICAL: ftagent returned an unparseable response."
    echo "Raw response: ${RESPONSE}"
    exit 1
fi

# Format BPS for readability
_fmt_bps() {
    local bps="$1"
    # Strip decimal for arithmetic
    local bps_int
    bps_int=$(echo "$bps" | cut -d. -f1)
    if [ -z "$bps_int" ] || ! echo "$bps_int" | grep -qE '^[0-9]+$'; then
        echo "${bps} bps"
        return
    fi
    if [ "$bps_int" -ge 1000000000 ]; then
        echo "$(echo "scale=1; $bps_int / 1000000000" | bc) Gbps"
    elif [ "$bps_int" -ge 1000000 ]; then
        echo "$(echo "scale=1; $bps_int / 1000000" | bc) Mbps"
    elif [ "$bps_int" -ge 1000 ]; then
        echo "$(echo "scale=1; $bps_int / 1000" | bc) Kbps"
    else
        echo "${bps} bps"
    fi
}

BPS_FMT=$(_fmt_bps "$CURRENT_BPS")

# Print summary line always
echo "ftagent v${VERSION} | interface: ${INTERFACE} | uptime: ${UPTIME}s | pps: ${CURRENT_PPS} | ${BPS_FMT}"

# Baseline not ready warning
if [ "$warn_no_baseline" = "1" ] && [ "$BASELINE_READY" = "false" ]; then
    echo "WARNING: Baseline not yet established. Attack detection is not active."
    exit 1
fi

# Attack status
if [ "$ATTACK_ACTIVE" = "true" ]; then
    echo "ALERT: DDoS attack in progress!"
    if [ -n "$INCIDENT_UUID" ] && [ "$INCIDENT_UUID" != "null" ]; then
        echo "Incident UUID: ${INCIDENT_UUID}"
    fi
    echo "Traffic: ${CURRENT_PPS} pps / ${BPS_FMT}"
    exit 1
fi

# All clear
echo "OK: No attack detected. Baseline ready: ${BASELINE_READY}."
exit 0
