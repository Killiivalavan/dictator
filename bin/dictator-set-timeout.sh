#!/usr/bin/env bash
# Set idle timeout in seconds (0 = never). Updates lifecycle.conf.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${DICTATOR_CONFIG_DIR:-$HOME/.config/dictator}"
LIFECYCLE="${DICTATOR_LIFECYCLE:-$CONFIG_DIR/lifecycle.conf}"
mkdir -p "$CONFIG_DIR"
val="${1:-300}"
if [[ "$val" == "never" ]]; then val=0; fi
[[ "$val" =~ ^[0-9]+$ ]] || { echo "invalid timeout" >&2; exit 1; }
if [[ -f "$LIFECYCLE" ]]; then
  if grep -qE '^[[:space:]]*idle_timeout_secs[[:space:]]*=' "$LIFECYCLE"; then
    sed -i "s/^[[:space:]]*idle_timeout_secs[[:space:]]*=.*/idle_timeout_secs=$val/" "$LIFECYCLE"
  else
    printf 'idle_timeout_secs=%s\n' "$val" >> "$LIFECYCLE"
  fi
else
  printf 'idle_timeout_secs=%s\n' "$val" > "$LIFECYCLE"
fi
echo "idle_timeout_secs=$val"
