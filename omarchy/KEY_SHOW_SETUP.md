# Show Me The Key — Keystroke Overlay on Hyprland (Omarchy)

This guide shows you how to show your keystrokes **on screen as a floating
overlay** (like GNOME/KDE's `screenkey`) instead of a tiled window, plus how to
place that overlay in **any** of five screen positions: center, top-left,
top-right, bottom-left, and bottom-right.

Useful for **online tutoring** and **streaming** sessions so your audience can
see exactly what you type.

---

## 1. About the app

**Show Me The Key (SMTK)** is a `screenkey` alternative that works on **both
X11 and Wayland**. It reads key events directly from `libinput`/`evdev`, so it
does **not** depend on the display protocol. This is why it works on Hyprland
(where classic `screenkey` does not).

| | |
|---|---|
| **Website** | <https://showmethekey.alynx.one/> |
| **GitHub repo** | <https://github.com/AlynxZhou/showmethekey> |
| **License** | Apache License 2.0 |
| **Arch package** | `showmethekey` (official `extra` repo) / `showmethekey-git` (AUR) |

> **Why is it already installed here?**
> Omarchy ships `showmethekey` by default (`/usr/bin/showmethekey-gtk` and
> `/usr/bin/showmethekey-cli`). You can confirm with:
> ```bash
> pacman -Q showmethekey
> which showmethekey-gtk
> ```

---

## 2. Installation (if you ever need to reinstall / build it fresh)

### Option A — Arch package (recommended on Omarchy)
```bash
sudo pacman -S showmethekey
```

### Option B — AUR git build (latest)
```bash
yay -S showmethekey-git   # yay is installed on this system
```

### Option C — Build from source
```bash
git clone https://github.com/AlynxZhou/showmethekey.git
cd showmethekey
mkdir build && cd build
meson setup --prefix=/usr . ..
meson compile
sudo meson install
```

---

## 3. How Show Me The Key works (important background)

SMTK is split into two parts:

- **`showmethekey-gtk`** — the GTK frontend. It draws **two** windows:
  - the **app/settings window** (title `Show Me The Key`), and
  - the **keys window** (title `Floating Window - Show Me The Key`) — this is
    the overlay you want.
- **`showmethekey-cli`** — the privileged backend that reads keyboard events
  from `/dev/input`. It needs **root** permission (SMTK triggers a `pkexec`
  prompt the first time).

SMTK stores its options in **GSettings** (dconf), not a config file:
```bash
gsettings list-recursively one.alynx.showmethekey
```

Key CLI flags (see `showmethekey-gtk --help`):
| Flag | Meaning |
|---|---|
| `-k, --keys-win` | Show the keys window on start |
| `-A, --no-app-win` | Hide the app/settings window, show only keys |
| `-C, --no-clickable` | Make the keys window click-through (unclickable) |

> **Critical Wayland fact:** *a Wayland client cannot set its own window
> position.* SMTK literally cannot place itself. Position is controlled by the
> compositor — in our case **Hyprland window rules** (Section 5).

---

## 4. Make it an overlay instead of a tiled window

On Hyprland/Omarchy, window behaviour is configured in `~/.config/hypr/`.
The file that controls window rules is **`~/.config/hypr/hyprland.lua`**.

The following is **already applied** on this machine (at the bottom of
`hyprland.lua`) — documented here so you can recreate or adjust it:

```lua
-- ~/.config/hypr/hyprland.lua  (bottom of file)

-- showmethekey: keep its windows floating and render the keystroke display as
-- an overlay (instead of a tiled window) without stealing focus.
o.window("one.alynx.showmethekey", { float = true, no_focus = true, pin = true })
```

Breaking this down:

| Field | Effect |
|---|---|
| `"one.alynx.showmethekey"` | Matches the window **class** (confirmed via `hyprctl clients`) |
| `float = true` | **Floats** the window → no longer occupies a tile; it's an overlay. **This fixes the "tiled window" problem.** |
| `no_focus = true` | The overlay never steals focus from the app you're typing in |
| `pin = true` | **Pins** it so it shows on **all workspaces** (always on top, like GNOME/KDE) |

> In Omarchy, `o.window(...)` is a helper that wraps Hyprland's native Lua API
> `hl.window_rule({ ... })`. Omarchy's config is **Lua** (not the old
> `windowrulev2` hyprlang syntax), so use the forms above.

After editing any Hyprland file, always reload and validate:
```bash
hyprctl reload
hyprctl configerrors     # ideally prints nothing / no errors
```

---

## 5. Position the overlay: center / top-left / top-right / bottom-left / bottom-right

Add a **second** `o.window` rule that targets the **keys window** specifically
and moves it. Only one of the `move`/`center` lines is active at a time —
**swap the line, save, and reload**.

The position variables available in Hyprland move expressions are:
`monitor_w`, `monitor_h` (screen size) and `window_w`, `window_h` (this window).
The numbers `80`/`60` below are just margin offsets you can tweak.

### Center (matches the current default)
```lua
o.window({ class = "one.alynx.showmethekey", title = "Floating Window - Show Me The Key" }, {
  center = true,
})
```

### Top-left
```lua
o.window({ class = "one.alynx.showmethekey", title = "Floating Window - Show Me The Key" }, {
  move = { "80", "60" },
})
```

### Top-right
```lua
o.window({ class = "one.alynx.showmethekey", title = "Floating Window - Show Me The Key" }, {
  move = { "(monitor_w-window_w-80)", "60" },
})
```

### Bottom-left
```lua
o.window({ class = "one.alynx.showmethekey", title = "Floating Window - Show Me The Key" }, {
  move = { "80", "(monitor_h-window_h-60)" },
})
```

### Bottom-right
```lua
o.window({ class = "one.alynx.showmethekey", title = "Floating Window - Show Me The Key" }, {
  move = { "(monitor_w-window_w-80)", "(monitor_h-window_h-60)" },
})
```

> These are **verified working** on this machine (Hyprland 0.56, Omarchy
> Lua config): the window reported `float: True`, and center / bottom-right
> produced the expected screen coordinates.

If you prefer **manual dragging**, you can instead omit the `move` line, keep
`float = true`, and — because SMTK is draggable when clickable — drag it where
you want. But **Wayland** fixes it to that spot once you stop dragging; a
`move` rule gives you pixel-exact placement every launch.

---

## 6. Keybinding to toggle the overlay on/off

`~/.config/hypr/bindings.lua` already contains a toggle on
**`SUPER + SHIFT + K`**:

```lua
o.bind("SUPER + SHIFT + K", "Show keystrokes", "bash -c 'N=show; N=${N}methekey-gtk; if pgrep -f \"$N -\" >/dev/null; then pkill -f \"$N\"; else sleep 1; setsid \"$N\" -A -k -C >/dev/null 2>&1 & disown; fi'")
```

What it does:

- If SMTK is **not** running → start it in **keys-only, no app window,
  click-through** mode: `showmethekey-gtk -A -k -C`.
- If SMTK **is** running → stop it.

> Why the `N=show; N=${N}methekey-gtk` trick? The running process name is
> `showmethekey-gtk` (17 chars) so `-x` matching fails, and the name isn't
> `/usr/bin/`-prefixed in its cmdline. Building the name at runtime lets
> `pgrep`/`pkill` match the real process **without the toggle accidentally
> matching itself**. The `sleep 1` avoids a GApplication single-instance race
> when relaunching. `setsid` fully detaches the overlay from the launching
> shell.

### Binding lookup
```bash
omarchy menu keybindings --print | grep -i "show keystrokes"
# -> SUPER SHIFT + K   Show keystrokes
```

---

## 7. Getting it to show keys on a plain launch

Symptoms reported during setup:
> "The app starts, but I cannot click on it to start showing the keys. It
> opens the app settings menu but doesn't show the keys."

This happens when **`active` is `false`** in SMTK's GSettings. The keys window
only shows when `active` is on. Enable it:
```bash
gsettings set one.alynx.showmethekey active true
gsettings get one.alynx.showmethekey active   # -> true
```

Also remember the CLI flags: plain `showmethekey-gtk` opens only the settings
window; use `-A -k -C` for a key-only overlay (which the keybinding already
does).

---

## 8. Full run-through (bare minimum to reproduce)

```bash
# 1. Ensure the app is installed
sudo pacman -S showmethekey

# 2. Make sure keys actually show by default
gsettings set one.alynx.showmethekey active true

# 3. hyprland.lua: float + pin + pick a position (Section 4 & 5)

# 4. bindings.lua: toggle binding (Section 6)

# 5. Reload Hyprland and verify
hyprctl reload
hyprctl configerrors

# 6. Toggle it on
#    press  SUPER + SHIFT + K
```

---

## 9. Troubleshooting

| Problem | Fix |
|---|---|
| Keys window appears **tiled**, not floating | Add `float = true` in the `o.window("one.alynx.showmethekey", ...)` rule |
| App opens **settings** window, no keys | `gsettings set one.alynx.showmethekey active true`; launch with `-A -k` |
| Overlay **steals focus** from what I'm typing | Add `no_focus = true` (already in the rule) |
| Overlay **disappears** when I switch workspace | Add `pin = true` (already in the rule) |
| Toggle **seems to do nothing** / only opens settings | A showmethekey instance may already be running single-instance; press the key again (it stops), then once more (it restarts in overlay mode) |
| Keys not shown for **remapped** keys | SMTK only sees low-level evdev events; remap via udev, not DE tools |
| Position **doesn't change** after editing | Confirm you edited the right file, saved, then ran `hyprctl reload` and check `hyprctl configerrors` |

---

## 10. Make the letters smaller & reduce spacing

The letters are **not** sized directly — they scale with the **size of the
floating window**, and the internal **spacing** is a separate setting. All of
these are stored in SMTK's GSettings and are safely adjustable.

### 10.1 Make the letters smaller (shrink the window)

The keys are drawn to fill the floating window's width/height, so a smaller
window = smaller letters.

```bash
gsettings set one.alynx.showmethekey width 900      # default 1500 pixels
gsettings set one.alynx.showmethekey height 120     # default 200 pixels
```

- Both accept any value `>= 0`.
- Because the Hyprland `center`/`move` rules use `window_w`/`window_h` in
  their expressions, the overlay **stays centered / in the chosen corner
  automatically** no matter what size you pick.
- Smaller values = smaller text; there's no separate "font size" setting.

### 10.2 Reduce the spacing around the letters

**`margin-ratio`** is the padding/margin between the keys and the window
edges. Lower it to pack the keys tighter (less empty space around them).

```bash
gsettings set one.alynx.showmethekey margin-ratio 0.25     # default 0.4
```

- Lower value = less spacing; `0` = keys flush to the edges. Start around
  `0.2`–`0.3` and tweak to taste.

### 10.3 Use compact key display mode

The **`mode`** setting controls how key combinations are rendered. `compact`
already merges and tightens the combination display (e.g. `Ctrl+Shift` shown
compactly), which reduces overall width.

```bash
gsettings set one.alynx.showmethekey mode compact   # 'composed' | 'raw' | 'compact'
```

### Recommended starting combo for a neat, small overlay

```bash
gsettings set one.alynx.showmethekey width 900
gsettings set one.alynx.showmethekey height 120
gsettings set one.alynx.showmethekey margin-ratio 0.25
gsettings set one.alynx.showmethekey mode compact
```

Restart the overlay with `SUPER + SHIFT + K` (toggle off, then on) to apply.
> This exact combination is **verified on this machine**: the overlay window
> rendered at `[900 x 120]` pixels, still centered at `[1270, 673]` on the
> 3440×1440 monitor.

---

## 11. References

- Project website: <https://showmethekey.alynx.one/>
- GitHub repository: <https://github.com/AlynxZhou/showmethekey>
- Releases: <https://github.com/AlynxZhou/showmethekey/releases>
- Hyprland window rules (Lua): <https://wiki.hypr.land/Configuring/Basics/Window-Rules/>

---

## 12. My Current Setup

The exact settings applied on this machine (as of setup) to reproduce the
current look: a **small, tight overlay fixed in the bottom-right corner**.

### Hyprland config — `~/.config/hypr/hyprland.lua`

```lua
-- showmethekey: keep its windows floating and render the keystroke display as
-- an overlay (instead of a tiled window) without stealing focus.
o.window("one.alynx.showmethekey", { float = true, no_focus = true, pin = true })

-- Bottom-right position (with 80px / 60px screen-edge margins).
o.window({ class = "one.alynx.showmethekey", title = "Floating Window - Show Me The Key" }, {
  move = { "(monitor_w-window_w-80)", "(monitor_h-window_h-60)" },
})
```

### Hyprland config — `~/.config/hypr/bindings.lua`

`SUPER + SHIFT + K` toggles the overlay on/off:

```lua
o.bind("SUPER + SHIFT + K", "Show keystrokes", "bash -c 'N=show; N=${N}methekey-gtk; if pgrep -f \"$N -\" >/dev/null; then pkill -f \"$N\"; else sleep 1; setsid \"$N\" -A -k -C >/dev/null 2>&1 & disown; fi'")
```

### Show Me The Key settings (GSettings)

```bash
gsettings set one.alynx.showmethekey active        true
gsettings set one.alynx.showmethekey width         760
gsettings set one.alynx.showmethekey height        80
gsettings set one.alynx.showmethekey margin-ratio  0.15
gsettings set one.alynx.showmethekey mode          compact
gsettings set one.alynx.showmethekey draw-border   false
```

### Resulting look (verified)

- Floating overlay window: **760 × 80 px**.
- Anchored **bottom-right** of the 3440×1440 monitor at `(2600, 1300)`.
- Letters small, padding tight, compact key-combination display, no border.
- Toggled with **`SUPER + SHIFT + K`**.

