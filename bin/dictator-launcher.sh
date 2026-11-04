#!/usr/bin/env bash
# Power-aware voxtype daemon launcher.
# Usage: dictator-launcher.sh daemon
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${DICTATOR_CONFIG_DIR:-}"
if [[ -z "$CONFIG_DIR" ]]; then
  if [[ -d "$SCRIPT_DIR/../config" ]]; then
    CONFIG_DIR="$SCRIPT_DIR/../config"
  else
    CONFIG_DIR="${HOME}/.config/dictator"
  fi
fi

# Detect AC power.
on_ac() {
  if command -v omarchy-power-present >/dev/null 2>&1; then
    omarchy-power-present && return 0
    return 1
  fi
  if command -v busctl >/dev/null 2>&1; then
    [[ "$(busctl get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower OnBattery 2>/dev/null)" == "b false" ]] && return 0
    return 1
  fi
  for supply in /sys/class/power_supply/*; do
    [[ -r "$supply/online" && -r "$supply/type" ]] || continue
    [[ "$(cat "$supply/type")" == "Mains" || "$(cat "$supply/type")" == "USB" ]] || continue
    [[ "$(cat "$supply/online")" == "1" ]] && return 0
  done
  return 1
}

if on_ac; then
  BINARY="/usr/lib/voxtype/voxtype-vulkan"
  CONFIG="$CONFIG_DIR/ac.toml"
  export VOXTYPE_VULKAN_DEVICE="${VOXTYPE_VULKAN_DEVICE:-nvidia}"
else
  BINARY="/usr/lib/voxtype/voxtype-avx2"
  CONFIG="$CONFIG_DIR/battery.toml"
fi

[[ -x "$BINARY" ]] || { echo "voxtype binary not found: $BINARY" >&2; exit 1; }
[[ -r "$CONFIG" ]] || { echo "config not found: $CONFIG" >&2; exit 1; }

if [[ "${1:-}" == "daemon" ]]; then
  exec "$BINARY" -c "$CONFIG" daemon
else
  # Print chosen invocation for debugging/wrappers.
  printf '%s\t%s\t%s\n' "$BINARY" "$CONFIG" "${VOXTYPE_VULKAN_DEVICE:-}"
fi
