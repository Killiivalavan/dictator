#!/usr/bin/env bash
# Manual warm/cold toggle for the voxtype daemon via systemd.
set -euo pipefail

if systemctl --user is-active --quiet dictator.service 2>/dev/null; then
  systemctl --user stop dictator.service
  echo "voxtype daemon stopped (cold)"
else
  systemctl --user start dictator.service
  echo "voxtype daemon starting (warm)"
fi
