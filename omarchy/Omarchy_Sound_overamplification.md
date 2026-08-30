# Omarchy Sound Overamplification Guide

Allows volume to go above 100% (up to the PipeWire ceiling of 150%) using the
volume media keys.

## Issue

The PipeWire / WirePlumber audio stack on Omarchy already supports
overamplification: the sink volume can be set to 150%, and `pactl` / `wpctl`
both report it correctly.

However, Omarchy's volume keybinding script
(`/usr/share/omarchy/bin/omarchy-audio-output-volume`, which your media keys
call) **clamps every volume step at 100%**. Consequences:

- `XF86AudioRaiseVolume` / `XF86AudioLowerVolume` never go above 100%.
- If you manually set the volume above 100% (e.g. `wpctl set-volume 34 150%`),
  the next press of a volume key recomputes from the current value and snaps it
  back down to 100%.
- `/usr/share/omarchy/` is packaged and read-only for user customization, so
  the shipped script cannot be edited in place (it would also be overwritten on
  the next `omarchy update`).

## Solution

Override the volume keybindings in user config and point them at a small user
script that mirrors the Omarchy script but allows a higher maximum.

### 1. Create the user volume script

Create `~/.local/bin/omarchy-volume-max` with the following content (the Omarchy
original, modified so `MAX_PERCENT=150` replaces the hardcoded `100` clamp):

```bash
#!/bin/bash

# Volume control allowing overamplification up to 150%.
# Mirror of omarchy-audio-output-volume with a higher ceiling.

MAX_PERCENT=150

action="${1:-}"

if [[ -z $action ]]; then
  echo "Usage: omarchy-volume-max <raise|lower|mute-toggle|+N|-N>"
  exit 1
fi

sink="$(omarchy-audio-output-sink)"
if [[ -z $sink ]]; then
  echo "Could not resolve an audio sink to control." >&2
  exit 1
fi

volume_percent() {
  pactl get-sink-volume "$sink" 2>/dev/null |
    awk 'NR == 1 {
      for (i = 1; i <= NF; i++)
        if ($i ~ /%$/) {sub("%", "", $i); print $i; exit}
    }'
}

volume_muted() {
  [[ $(pactl get-sink-mute "$sink" 2>/dev/null) == *yes ]]
}

case "$action" in
  raise) action="+5" ;;
  lower) action="-5" ;;
esac

if [[ $action == "mute-toggle" ]]; then
  runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
  debounce_file="$runtime_dir/omarchy-volume-max-mute-toggle.last"
  now=$(date +%s%3N)
  last=0
  [[ -r $debounce_file ]] && read -r last <"$debounce_file" || true
  if ((now - last < 250)); then
    exit 0
  fi
  printf '%s\n' "$now" >"$debounce_file"

  pactl set-sink-mute "$sink" toggle
elif [[ $action =~ ^([+-])([0-9]+)$ ]]; then
  direction="${BASH_REMATCH[1]}"
  step="${BASH_REMATCH[2]}"

  current="$(volume_percent)"
  if [[ -z $current ]]; then
    echo "Could not read volume for $sink." >&2
    exit 1
  fi

  if [[ $direction == "+" ]]; then
    next=$((current + step))
    ((next <= MAX_PERCENT)) || next=$MAX_PERCENT
  else
    next=$((current - step))
    ((next >= 0)) || next=0
  fi

  pactl set-sink-mute "$sink" 0
  pactl set-sink-volume "$sink" "${next}%"
else
  echo "Unknown volume action: $action"
  exit 1
fi

percent=$(volume_percent)
if volume_muted || ((${percent:-0} == 0)); then
  icon="volume-muted"
else
  icon="volume-high"
fi

omarchy-osd -i "$icon" -p "${percent:-0}"
```

Make it executable:

```bash
chmod +x ~/.local/bin/omarchy-volume-max
```

`~/.local/bin` must be on `PATH` (it is by default on Omarchy); verify with
`command -v omarchy-volume-max`.

### 2. Rebind the volume keys

Edit `~/.config/hypr/bindings.lua` and add, before any conflicting bindings:

```lua
-- Volume keys allow overamplification up to 150% (defaults clamp at 100%)
hl.unbind("XF86AudioRaiseVolume")
hl.unbind("XF86AudioLowerVolume")
hl.unbind("ALT + XF86AudioRaiseVolume")
hl.unbind("ALT + XF86AudioLowerVolume")
o.bind("XF86AudioRaiseVolume", "Volume up", "omarchy-volume-max raise", { locked = true, repeating = true })
o.bind("XF86AudioLowerVolume", "Volume down", "omarchy-volume-max lower", { locked = true, repeating = true })
o.bind("ALT + XF86AudioRaiseVolume", "Volume up precise", "omarchy-volume-max +1", { locked = true, repeating = true })
o.bind("ALT + XF86AudioLowerVolume", "Volume down precise", "omarchy-volume-max -1", { locked = true, repeating = true })
```

Notes:
- `hl.unbind` is required first because the default bindings already bind these
  keys (`Volume up` / `Volume down` / `Volume up precise` / `Volume down
  precise` in Omarchy's `media.lua`).
- The mute key (`XF86AudioMute`) is unaffected by the 100% clamp and keeps its
  default binding, so it does not need overriding.

### 3. Reload and validate

```bash
hyprctl reload
hyprctl configerrors
```

`configerrors` must report no errors.

### 4. Test

```bash
wpctl set-volume <sink-id> 1.0   # normalize to 100%
omarchy-volume-max raise         # expected: 105%
omarchy-volume-max +50           # expected: clamps at 150%
omarchy-volume-max -50           # expected: back to 100%
```

The volume OSD shows the real percentage above 100% as well.

## Summary

| Piece | Location |
|-------|----------|
| Overamplification script (max 150%) | `~/.local/bin/omarchy-volume-max` |
| Keybinding overrides | `~/.config/hypr/bindings.lua` |

Hard ceiling (150%) comes from PipeWire / WirePlumber; raising it further would
require WirePlumber policy changes and is not covered here.