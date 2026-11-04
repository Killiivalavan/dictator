#!/usr/bin/env bash
set -uo pipefail
CONFIG_DIR="${DICTATOR_CONFIG_DIR:-$HOME/.config/dictator}"
LIFECYCLE="${DICTATOR_LIFECYCLE:-$CONFIG_DIR/lifecycle.conf}"
if [[ -r "$LIFECYCLE" ]]; then
  t="$(grep -E '^[[:space:]]*idle_timeout_secs[[:space:]]*=' "$LIFECYCLE" | tail -1 | cut -d= -f2 | tr -d '[:space:]')"
  [[ "$t" =~ ^[0-9]+$ ]] && { echo "$t"; exit 0; }
fi
echo 300
