# Dictator — Power-aware, lifecycle-managed Voxtype for Omarchy

Dictator wraps the stock Omarchy `voxtype` setup with a power-aware daemon
launcher, lazy hotkey startup, idle auto-stop, a manual warm/cold toggle,
and a Quickshell bar widget. It is designed to sit **on top of** stock
Omarchy without modifying any system files, so Omarchy updates cannot
overwrite it.

## Design principles (non-disruptive)

- **No system files are edited.** Stock `voxtype.service`, `/usr/bin/voxtype`,
  `/usr/share/omarchy/...` are left untouched. Dictator ships its own user
  systemd units, scripts in `~/.local/bin`, configs in `~/.config/dictator`,
  and a user-level Quickshell plugin.
- **Stock service is disabled**, not removed. `systemctl --user disable --now
  voxtype.service` keeps the unit file intact for rollback; Dictator's
  `dictator.service` takes over.
- **All runtime state lives under `~/.config/dictator`, `~/.local/bin`,
  `~/.config/systemd/user`, and `~/.config/omarchy/plugins`.** Omarchy
  package updates touch `/usr/share/...` and `/usr/bin/...` only.
- **Rollback is trivial:** disable Dictator units, re-enable `voxtype.service`.

## Requirements

- Omarchy with `voxtype` installed (stock).
- `voxtype-vulkan` variant installed (for GPU path): `voxtype setup gpu --enable`
  or `voxtype setup variant --to voxtype-vulkan`.
- NVIDIA GPU present and Vulkan runtime installed (for AC profile).
- Quickshell-based Omarchy bar (stock).

## Directory layout

```
~/Code/dictator/
├── bin/                  # scripts (install to ~/.local/bin)
│   ├── dictator-launcher.sh
│   ├── dictator-hotkey.sh
│   ├── dictator-toggle.sh
│   ├── dictator-watcher.sh
│   ├── dictator-get-timeout.sh
│   └── dictator-set-timeout.sh
├── config/               # install to ~/.config/dictator
│   ├── base.toml         # reference copy of stock config
│   ├── ac.toml           # AC profile: NVIDIA, medium.en, streaming on
│   ├── battery.toml      # battery profile: CPU, small.en, streaming off
│   └── lifecycle.conf    # idle_timeout_secs (0 = never)
├── plugin/               # install to ~/.config/omarchy/plugins/killie.dictator
│   ├── manifest.json
│   └── BarWidget.qml
├── systemd/              # install to ~/.config/systemd/user
│   ├── dictator.service
│   └── dictator-watcher.service
└── README.md
```

## Fresh-install procedure

### 1. Prerequisites

```bash
voxtype setup gpu --enable          # installs/selects vulkan variant
voxtype setup --download --model medium.en
voxtype setup --download --model small.en
```

### 2. Install scripts

```bash
mkdir -p ~/.local/bin ~/.config/dictator ~/.config/systemd/user
cp ~/Code/dictator/bin/* ~/.local/bin/
chmod +x ~/.local/bin/dictator-*.sh
cp ~/Code/dictator/config/* ~/.config/dictator/
```

### 3. Install systemd units

```bash
cp ~/Code/dictator/systemd/* ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user disable --now voxtype.service      # keep unit, stop auto-start
systemctl --user enable --now dictator.service
systemctl --user enable --now dictator-watcher.service
```

### 4. Hyprland keybinding

In `~/.config/hypr/bindings.lua`, bind Super+Ctrl+X to the hotkey wrapper:

```lua
o.bind("SUPER + CTRL + X", "Toggle dictation", "dictator-hotkey.sh")
```

(Remove or leave the stock `voxtype record toggle` binding; Dictator's wrapper
supersedes it.)

### 5. Quickshell bar widget

```bash
mkdir -p ~/.config/omarchy/plugins/killie.dictator
cp ~/Code/dictator/plugin/* ~/.config/omarchy/plugins/killie.dictator/
```

Then add `killie.dictator` to your bar layout in `~/.config/omarchy/shell.json`
(replacing or supplementing the stock `Dictation` indicator). Reload the shell
(`omarchy-restart-shell`) or log out/in.

### 6. Verify

```bash
systemctl --user status dictator.service
voxtype status
voxtype info accel          # expect gpu/vulkan on AC, cpu-only on battery
```

## Runtime behavior

- **AC power:** `dictator.service` runs `voxtype-vulkan` with `ac.toml`
  (medium.en, streaming + eager processing on, flash attention on, 10 s
  meeting chunks). `VOXTYPE_VULKAN_DEVICE=nvidia` forces the dGPU.
- **Battery power:** runs `voxtype-avx2` with `battery.toml`
  (small.en, streaming off, on-demand loading on, 30 s meeting chunks).
- **Power transition:** the launcher is re-evaluated only when a new daemon
  starts. If a transition happens while a daemon is running, the current
  daemon keeps running until it stops (idle timeout or manual toggle), then
  the next start picks the correct profile. To force an immediate swap,
  toggle the daemon off and on.
- **Lazy start:** the daemon is not started at boot. The hotkey wrapper
  starts it on first use; the model stays warm afterwards.
- **Idle auto-stop:** `dictator-watcher.service` stops the daemon after
  `idle_timeout_secs` seconds of idle (default 300). Set to 0 to disable.
  Inhibited while a meeting is active.
- **Manual toggle:** `dictator-toggle.sh` or the bar widget button.

## Bar widget

- Plugin id: `killie.dictator`.
- Left click: warm/cold toggle of the daemon.
- Right click: popup with "never auto-end" checkbox and idle-timeout slider.
  - Slider: 30 s … 5 min in 30 s steps, then 5 … 60 min in 5 min steps.
  - Checkbox greys out the slider and sets timeout to 0 (never).
- Tooltip shows daemon state (warm/cold).

## Configuration knobs

- `~/.config/dictator/ac.toml` / `battery.toml` — model, streaming, meeting
  chunk size, audio device, etc. (standard voxtype config).
- `~/.config/dictator/lifecycle.conf` — `idle_timeout_secs=<n>` (0 = never).
- `VOXTYPE_VULKAN_DEVICE` env (set in the service unit) — `nvidia` or `amd`.

## Rollback

```bash
systemctl --user disable --now dictator.service dictator-watcher.service
systemctl --user enable --now voxtype.service
# remove ~/.config/omarchy/plugins/killie.dictator if desired
```

Stock Omarchy behavior is fully restored.

## Troubleshooting

- **Daemon won't start:** check `journalctl --user -u dictator.service`.
  Common cause: config path wrong (verify `DICTATOR_CONFIG_DIR`).
- **GPU not used on AC:** verify `voxtype setup gpu --status` shows Vulkan
  installed and `VOXTYPE_VULKAN_DEVICE=nvidia` in the service environment.
- **Auto-stop not triggering:** ensure `dictator-watcher.service` is active
  and `lifecycle.conf` is readable; check `voxtype meeting status` isn't
  reporting an active meeting.
- **Bar widget missing:** confirm plugin directory name matches manifest id
  (`killie.dictator`) and that it is listed in `shell.json`.

## Files in this repository

See directory layout above. All source lives here so the setup can be
reproduced on a fresh Omarchy install by following this document.
