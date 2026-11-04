#!/usr/bin/env bash
# Hotkey wrapper: ensure daemon is running for current power state, then toggle recording.
set -euo pipefail

if ! systemctl --user is-active --quiet dictator.service 2>/dev/null; then
  systemctl --user start dictator.service
  # Wait for readiness (up to 10s).
  for i in $(seq 1 50); do
    if systemctl --user is-active --quiet dictator.service 2>/dev/null && voxtype status >/dev/null 2>&1; then
      break
    fi
    sleep 0.2
  done
fi

exec voxtype record toggle
