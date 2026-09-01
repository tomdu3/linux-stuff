# Wacom Intuos BT S — Stylus Mapping on Omarchy (Hyprland)

How to control where the Wacom Intuos stylus maps on screen (single monitor,
sub-region / window, or a reduced physical tablet area) — plus runtime toggles —
the native Hyprland way, no extra app needed.

## Prerequisites

- Omarchy (Arch + Hyprland ≥ 0.55, Lua config)
- Wacom Intuos BT S connected via Bluetooth/USB
- No `xsetwacom` needed: it only works under X11, not Wayland

## 1. Identify your device name

Get the exact **Tablet** name (not `Tablet Pad`, not `Tablet Tool`):

```bash
hyprctl devices
```

You should see something like:

```
Tablets:
	Tablet at 55c2ad391210:
		wacom-intuos-bt-s-pen
			size: 152x95mm
```

For the Intuos BT S the pen device is `wacom-intuos-bt-s-pen`. Use this name
in every config block below.

## 2. List your monitors

```bash
hyprctl monitors
```

Note the monitor names (`HDMI-A-1`, `DP-1`, …). The examples below assume:

| Monitor  | Resolution  | Position | Notes            |
|----------|-------------|----------|------------------|
| HDMI-A-1 | 3440x1440   | 0x0      | Ultrawide, main  |
| DP-1     | 1920x1080   | 3440x0   | Secondary (right)|

## 3. Configure the mapping

Edit `~/.config/hypr/input.lua` and add a `hl.device({ ... })` block:

```lua
-- Wacom Intuos BT S pen
hl.device({
    name = "wacom-intuos-bt-s-pen",
    output = "DP-1",                  -- lock stylus to one monitor
})
```

Apply and validate:

```bash
hyprctl reload
hyprctl configerrors   # must be empty
```

Hyprland also reloads automatically when the file is saved.

### Lock to one screen

```lua
hl.device({
    name = "wacom-intuos-bt-s-pen",
    output = "DP-1",                  -- or "HDMI-A-1", or "current"
})
```

- `"current"` follows the monitor the cursor is on.
- Empty `output` maps across all monitors (the default).

### Map to a sub-region (window-sized area)

`region_position` / `region_size` are in **pixel** coordinates. With
`output` empty they are absolute in the global layout; with an `output` set
they are relative to that monitor's top-left.

```lua
hl.device({
    name = "wacom-intuos-bt-s-pen",
    output = "",                      -- absolute coords across all monitors
    region_position = { 3540, 100 },  -- top-left of the mapped region
    region_size = { 1600, 900 },      -- width/height of the mapped region
})
```

- On the example layout, `HDMI-A-1` spans `0..3440` x `0..1440` and `DP-1`
  starts at `x = 3440`, so a region on the BenQ uses `region_position` x `>= 3440`.
- You can also add `absolute_region_position = true`. Only applies when
  `output` is empty.

### Reduce the physical drawing area

`active_area_position` / `active_area_size` are in **millimetres** on the tablet
surface (full Intuos BT S surface: `152 x 95` mm).

```lua
hl.device({
    name = "wacom-intuos-bt-s-pen",
    output = "DP-1",
    active_area_position = { 13, 15 },   -- top-left of used surface
    active_area_size = { 126, 65 },      -- keep ~5/6 width, ~2/3 height
})
```

Useful to shrink the usable surface so fewer wrist movements cross the screen,
or to match the monitor's aspect ratio so a drawn circle stays a circle.

### Rotate / left-handed

```lua
hl.device({
    name = "wacom-intuos-bt-s-pen",
    output = "DP-1",
    left_handed = true,     -- equivalent to 180-degree rotation
    transform = 0,          -- or 90 / 180 / 270 (same values as monitors)
})
```

### Full reference of tablet options

| Option                   | Type      | Meaning                                        |
|--------------------------|-----------|------------------------------------------------|
| `output`                 | string    | Monitor to bind to (`"current"` or name; empty = all) |
| `region_position`        | vec2      | Mapped region top-left, in pixels              |
| `region_size`            | vec2      | Mapped region size in pixels (`{0,0}` = unset) |
| `absolute_region_position` | bool   | Treat region_position as absolute in the layout (only when output empty) |
| `active_area_position`   | vec2      | Tablet surface top-left used, in mm            |
| `active_area_size`       | vec2      | Tablet surface size used, in mm                |
| `transform`              | int       | Rotation: 0 / 90 / 180 / 270                   |
| `left_handed`            | bool      | Rotate tablet 180 degrees                      |
| `relative_input`         | bool      | Treat pen like a relative mouse                |

## 4. Toggle mapping at runtime (bind a script)

Config changes in `input.lua` are static. For on-the-fly switching (e.g. "map to
the currently focused window"), use `hyprctl eval` to re-apply device options
without editing files:

```bash
# Map the pen to the focused window
hyprctl eval 'local w = hl.get_active_window(); hl.device({ name = "wacom-intuos-bt-s-pen", output = "", region_position = { w.at.x, w.at.y }, region_size = { w.size.x, w.size.y } })'

# Reset to default mapping (DP-1, full area)
hyprctl eval 'hl.device({ name = "wacom-intuos-bt-s-pen", output = "DP-1", region_position = { 0, 0 }, region_size = { 0, 0 } })'

# Switch target monitor
hyprctl eval 'hl.device({ name = "wacom-intuos-bt-s-pen", output = "HDMI-A-1" })'
```

Window object fields (from `hl.get_active_window()`): `at.x`, `at.y` =
top-left position, `size.x`, `size.y` = width, height — all in the global
layout, in pixels.

Note: `eval` answers `ok` on success. You can inspect the results of any line by
prefixing with `repl` instead of `eval`.

### Example scripts

`~/.local/bin/wacom-map-focused`:

```bash
#!/usr/bin/env bash
# Map the Wacom pen to the currently focused window ('reset' restores DP-1).
name="wacom-intuos-bt-s-pen"
if [ "${1:-}" = "reset" ]; then
  hyprctl eval "hl.device({ name = \"$name\", output = \"DP-1\", region_position = { 0, 0 }, region_size = { 0, 0 } })"
  exit 0
fi
hyprctl eval "local w = hl.get_active_window(); hl.device({ name = \"$name\", output = \"\", region_position = { w.at.x, w.at.y }, region_size = { w.size.x, w.size.y } })"
```

Make it executable and a second file to switch to the ultrawide:

```bash
chmod +x ~/.local/bin/wacom-map-focused
```

`~/.local/bin/wacom-map-ultrawide`:

```bash
#!/usr/bin/env bash
hyprctl eval 'hl.device({ name = "wacom-intuos-bt-s-pen", output = "HDMI-A-1" })'
```

```bash
chmod +x ~/.local/bin/wacom-map-ultrawide
```

### Add keybindings

Edit `~/.config/hypr/bindings.lua`. Check for conflicts first:

```bash
omarchy menu keybindings --print
```

Then add (a string command becomes `hl.dsp.exec_cmd`):

```lua
o.bind("SUPER + SHIFT + T", "Map tablet to focused window", "wacom-map-focused")
o.bind("SUPER + SHIFT + R", "Reset tablet region", "wacom-map-focused reset")
-- if a key is already bound, call hl.unbind(...) before the new o.bind(...)
```

Apply:

```bash
hyprctl reload && hyprctl configerrors
```

## 5. Troubleshooting

| Symptom                            | Fix                                                        |
|------------------------------------|------------------------------------------------------------|
| Stylus not working at all          | `hyprctl devices` — confirm tablet listed; check Bluetooth connection |
| Wrong monitor                      | Double-check `output` name via `hyprctl monitors`           |
| Region placement looks wrong       | `region_position` is relative to the bound monitor, or absolute when `output` is empty — remember layout offsets (e.g. BenQ starts at x=3440) |
| Nothing changed after editing      | `hyprctl reload && hyprctl configerrors`                   |
| Toggle script maps to wrong place  | Verify geometry with `hyprctl repl 'local w = hl.get_active_window(); return string.format("%d,%d %dx%d", w.at.x, w.at.y, w.size.x, w.size.y)'` |
| Want a GUI instead                 | KDE's kcm_wacomtablet (Plasma) or OpenTabletDriver (heavy; conflicts with Hyprland's own mapping) |

## Quick reference

```bash
hyprctl devices                 # device name
hyprctl monitors                # monitor names / layout
hyprctl reload && hyprctl configerrors
hyprctl eval '...lua...'        # apply device options on the fly
hyprctl repl '...expr...'       # evaluate and print a value
```