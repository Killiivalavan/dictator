#!/usr/bin/env bash
# Auto-stop voxtype daemon after idle timeout (0 = never).
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${DICTATOR_CONFIG_DIR:-$HOME/.config/dictator}"
LIFECYCLE="${DICTATOR_LIFECYCLE:-$CONFIG_DIR/lifecycle.conf}"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/dictator-idle-since"

read_timeout() {
  local t=300
  if [[ -r "$LIFECYCLE" ]]; then
    t="$(grep -E '^[[:space:]]*idle_timeout_secs[[:space:]]*=' "$LIFECYCLE" | tail -1 | cut -d= -f2 | tr -d '[:space:]')"
    [[ "$t" =~ ^[0-9]+$ ]] || t=300
  fi
  printf '%s' "$t"
}

meeting_active() {
  voxtype meeting status 2>/dev/null | grep -qiE 'recording|paused|active'
}

daemon_running() {
  pgrep -f "voxtype.*daemon" >/dev/null 2>&1
}

idle_now() {
  [[ "$(voxtype status 2>/dev/null)" == "idle" ]]
}

while true; do
  timeout="$(read_timeout)"
  if ! daemon_running; then
    rm -f "$STATE_FILE"
    sleep 30
    continue
  fi
  if meeting_active; then
    rm -f "$STATE_FILE"
    sleep 30
    continue
  fi
  if idle_now; then
    if [[ ! -f "$STATE_FILE" ]]; then
      date +%s > "$STATE_FILE"
    fi
    idle_since="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
    now="$(date +%s)"
    elapsed=$((now - idle_since))
    if [[ "$timeout" -ne 0 && "$elapsed" -ge "$timeout" ]]; then
      systemctl --user stop dictator.service 2>/dev/null || pkill -f "voxtype.*daemon" 2>/dev/null || true
      rm -f "$STATE_FILE"
    fi
  else
    rm -f "$STATE_FILE"
  fi
  sleep 30
done
