#!/bin/bash
#SYNOPSIS
#   Checks gobetween TCP load balancer health
#
#DESCRIPTION
#   Monitors gobetween process, port listeners, backend connectivity,
#   active connections, and recent errors. Runs via RMM agent.
#   Returns Nagios-style exit codes (0=OK, 1=WARNING, 2=CRITICAL).
#
#PARAMETER debug
#     Set env debug=1 for verbose per-backend test output to stderr
#
#NOTES
#   Author: SAN
#   Date: 02.06.26
#   #public
#
#CHANGELOG


STATUS=0
OUTPUT=""
PERFDATA=""
CONFIG="/etc/gobetween/gobetween.toml"
PORTS=(80 443 25 993)
VERBOSE=false
[[ "${debug:-0}" == "1" || "${DEBUG:-0}" == "1" ]] && VERBOSE=true
# --- 1. Process check ---
PID=$(pgrep -x gobetween)
if [[ -z "$PID" ]]; then
  echo "GOBETWEEN CRITICAL - gobetween process not running | active_conns=0"
  exit 2
fi
$VERBOSE && echo "[DEBUG] gobetween PID: $PID" >&2
# --- 2. Port listeners ---
DOWN_PORTS=()
for PORT in "${PORTS[@]}"; do
  ss -tlnp 2>/dev/null | grep -qE ":${PORT}\s" || DOWN_PORTS+=("$PORT")
done
$VERBOSE && echo "[DEBUG] expected ports: ${PORTS[*]}, down: ${DOWN_PORTS[*]:-none}" >&2
if [[ ${#DOWN_PORTS[@]} -gt 0 ]]; then
  OUTPUT+="ports down: ${DOWN_PORTS[*]}; "
  STATUS=2
fi
# --- 3. Backend connectivity ---
DOWN_BE=0
BE_COUNT=0
DOWN_LIST=()
while IFS= read -r line; do
  trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')
  [[ -z "$trimmed" || "$trimmed" == \#* || "$trimmed" != *\"* ]] && continue
  ip=$(echo "$line" | sed -n 's/.*"\([^"]*\)".*/\1/p')
  [[ -z "$ip" || "$ip" != *":"* ]] && continue
  BE_COUNT=$((BE_COUNT + 1))
  IP="${ip%:*}"
  PORT="${ip##*:}"
  $VERBOSE && echo -n "[DEBUG] testing $ip ... " >&2
  if ! timeout 3 bash -c "echo > /dev/tcp/$IP/$PORT" 2>/dev/null; then
    DOWN_BE=$((DOWN_BE + 1))
    DOWN_LIST+=("$ip")
    $VERBOSE && echo "FAIL" >&2
  else
    $VERBOSE && echo "OK" >&2
  fi
done < <(grep -A50 'static_list' "$CONFIG" | grep '"')
$VERBOSE && echo "[DEBUG] $BE_COUNT backends tested, $DOWN_BE down" >&2
if [[ $DOWN_BE -gt 0 ]]; then
  PCT_DOWN=$((DOWN_BE * 100 / BE_COUNT))
  FAILS=$(IFS=,; echo "${DOWN_LIST[*]}")
  if [[ $PCT_DOWN -ge 50 ]]; then
    OUTPUT+="${DOWN_BE}/${BE_COUNT} backends unreachable [${FAILS}]; "
    STATUS=2
  else
    OUTPUT+="${DOWN_BE}/${BE_COUNT} backends unreachable [${FAILS}]; "
    [[ $STATUS -eq 0 ]] && STATUS=1
  fi
fi
# --- 4. Active connections ---
ACTIVE_CONNS=$( (sudo netstat -tpn 2>/dev/null || ss -tpn 2>/dev/null) | grep -c "gobetween" )
PERFDATA="active_conns=$ACTIVE_CONNS"
$VERBOSE && echo "[DEBUG] active connections: $ACTIVE_CONNS" >&2
if [[ $ACTIVE_CONNS -gt 10000 ]]; then
  OUTPUT+="connections high ($ACTIVE_CONNS); "
  [[ $STATUS -eq 0 ]] && STATUS=1
fi
# --- 5. Recent errors ---
ERROR_COUNT=$(journalctl -u gobetween --since "5 min ago" --no-pager 2>/dev/null | grep -cP '\[ERROR\]|\[PANIC\]|\[FATAL\]')
$VERBOSE && echo "[DEBUG] recent errors: $ERROR_COUNT" >&2
if [[ $ERROR_COUNT -gt 10 ]]; then
  OUTPUT+="$ERROR_COUNT errors in 5m; "
  STATUS=2
elif [[ $ERROR_COUNT -gt 0 ]]; then
  OUTPUT+="$ERROR_COUNT errors in 5m; "
  [[ $STATUS -eq 0 ]] && STATUS=1
fi
# --- 6. Config file exists ---
if [[ ! -f "$CONFIG" ]]; then
  OUTPUT+="config missing; "
  STATUS=2
fi
# --- Output ---
case $STATUS in
  0) echo "GOBETWEEN OK - all checks passed | $PERFDATA" ;;
  1) echo "GOBETWEEN WARNING - ${OUTPUT%; } | $PERFDATA" ;;
  2) echo "GOBETWEEN CRITICAL - ${OUTPUT%; } | $PERFDATA" ;;
esac
exit $STATUS