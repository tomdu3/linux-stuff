# GIF Screen Capture (Omarchy)

Record your screen and save it as an animated GIF.

---

## Quick start

Press <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>G</kbd>, drag a region, and press the
same key again to stop. The GIF lands in `~/Pictures` and its path is copied to
your clipboard.

From a terminal:

```bash
omarchy-capture-gif                      # region picker, then writes a GIF
omarchy-capture-gif --fullscreen         # capture the focused monitor, no picker
omarchy-capture-gif --fullscreen --duration=10
```

Pressing the shortcut again while a recording is running stops it and writes
the GIF, so the same key both starts and stops.

---

## Keyboard shortcuts

This keyboard has no <kbd>Print</kbd> key, so Omarchy's default capture
shortcuts (which all use <kbd>Print</kbd>) were unreachable. They have been
re-mapped onto the <kbd>Super</kbd> + <kbd>Shift</kbd> row.

| Shortcut | Action |
|---|---|
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>G</kbd> | **GIF recording** — start, press again to stop and write |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>G</kbd> | GIF recording (same action, second position) |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>S</kbd> | Screenshot |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd> | Screen recording (mp4) |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>T</kbd> | Extract text (OCR) from a region |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>H</kbd> | Colour picker |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>C</kbd> | Capture menu (everything above, in one list) |

The original <kbd>Print</kbd> bindings are still present in Omarchy's defaults
and still work if you ever plug in a keyboard that has one:

| Shortcut | Action |
|---|---|
| <kbd>Super</kbd>+<kbd>Alt</kbd>+<kbd>Print</kbd> | GIF recording (also bound to this script) |
| <kbd>Print</kbd> | Screenshot |
| <kbd>Alt</kbd>+<kbd>Print</kbd> | Screen recording (mp4) |
| <kbd>Super</kbd>+<kbd>Print</kbd> | Colour picker |
| <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>Print</kbd> | Extract text (OCR) |

> <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>G</kbd> previously launched Signal.
> Signal is not installed on this machine, so the binding was dead and has been
> reused for the GIF recorder.

---

## The menu

<kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>C</kbd> opens the Capture menu, which now has a
**GIF** submenu:

- **Region** — pick a region and record
- **Fullscreen** — record the focused monitor
- **Stop GIF** — only shown while a GIF recording is running

The Capture menu is also reachable with `omarchy menu summon capture`, and the
alias `gif` was added, so `omarchy menu summon gif` opens it too.

---

## Command reference

```
omarchy-capture-gif [options]

  --fullscreen          Capture the focused monitor instead of asking for a region.
  --fps=<fps>           Frames per second in the GIF (default: 20).
  --width=<pixels>      Maximum GIF width; smaller regions keep their size (default: 1000).
  --duration=<seconds>  Stop automatically after this many seconds.
  --stop-recording      Stop the running capture and write the GIF.
  --active              Exit successfully while a capture is running, otherwise fail.
  -h, --help            Show help.
```

Running the command again while a capture is running stops it and writes the
GIF.

### Where the output goes

`~/Pictures/gif-YYYY-MM-DD_HH-MM-SS.gif`

Override the directory with `OMARCHY_GIF_DIR`, for example:

```bash
OMARCHY_GIF_DIR=~/Videos omarchy-capture-gif
```

The GIF's `file://` URI is copied to the clipboard as a URI list, so it pastes
straight into a chat or a document as an image. A notification with a
thumbnail appears when it is ready; clicking it opens the GIF in `mpv`.

---

## How it works

1. **Capture** — the script calls `omarchy-capture-screenrecording`, Omarchy's
   own screen recording flow, which drives `gpu-screen-recorder`. This means
   the region picker, the bar indicator, and the "Stop Screenrecording" menu
   row all behave exactly as they do for mp4 recordings. The intermediate mp4
   is kept in `~/Videos`.
2. **Watch** — a background watcher tracks the recorder process. The GIF is
   written no matter how the recording was stopped: the shortcut, the menu
   row, or the bar indicator.
3. **Encode** — ffmpeg converts the clip with a clip-wide palette:

   ```
   fps=20,scale='min(1000,iw)':-2:flags=lanczos,split[s0][s1];
   [s0]palettegen[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3
   ```

   `palettegen` builds the 256-colour palette from the whole clip rather than
   sampling one frame, and `paletteuse` applies it with bayer dithering so
   gradients do not band.
4. **Optimise** — `gifsicle --optimize=3 --lossy=60` shrinks the result by
   about 37% with no visible difference (PSNR ~40 dB), merging identical
   consecutive frames and cropping each frame to the region that changed.

Runtime state lives in `$XDG_RUNTIME_DIR`:

- `omarchy-capture-gif.state` — the running recording's pid, clip path and settings
- `omarchy-capture-gif.log` — ffmpeg/gifsicle output, checked when encoding fails

---

## Tuning

| Want | Use |
|---|---|
| Smaller file | `--width=600` (or `--width=800`) |
| Smoother motion | `--fps=30` — roughly 1.5× the file size |
| Smaller file, choppier motion | `--fps=12` or `--fps=15` |
| Full-resolution output | `--width=100000` effectively disables the cap; expect large files |

`--width` is a maximum, not a target: a region narrower than the limit keeps
its own size and is not upscaled.

---

## Troubleshooting

**No GIF appeared.** Check the log:

```bash
cat "${XDG_RUNTIME_DIR:-/tmp}/omarchy-capture-gif.log"
```

**The recording did not start.** Another screen recording was already running.
Omarchy's toggle logic would otherwise hijack it, so the script refuses and
shows a notification. Stop the other recording first.

**The GIF looks blocky or banded.** Lower `--fps` (fewer colours are needed
for slower content) or narrow the region. Palette generation is already
clip-wide, so this is usually a content issue, not an encoder one.

**Nothing happens when pressing the shortcut.** Check the binding is live:

```bash
omarchy menu keybindings --print | grep -i gif
```

**A recording is stuck running.** Stop it and let the watcher finish:

```bash
omarchy-capture-gif --stop-recording
```

---

## Packages installed

| Package | Version | Why |
|---|---|---|
| `gifsicle` | 1.98-1 | GIF optimisation pass |
| `wf-recorder` | 0.6.0-2 | The dedicated wlroots screen recorder |

`wf-recorder` is installed but **not** used by this script. Its native
`--codec gif` output was benchmarked against this pipeline and lost on both
counts:

- On the rotated `HDMI-A-1` monitor it produced a **0-byte file** — its
  `transpose=1` filter chain fails on rotated output.
- It encodes `rgb8` with no palette optimisation and offers no downscaling, so
  a 3440×1440 GIF came out at **1.06 MB for 5 seconds**, versus 424 KB for
  the palettegen pipeline at a usable width.

The Omarchy `gpu-screen-recorder` backend handles the rotated monitor
correctly and integrates with the bar indicator, so it is the better base.
`wf-recorder` remains available as a standalone recorder.

---

## Files

| Path | Purpose |
|---|---|
| `~/.local/bin/omarchy-capture-gif` | The command |
| `~/.config/hypr/bindings.lua` | The shortcuts above |
| `~/.config/omarchy/extensions/omarchy-menu.jsonc` | The Capture → GIF menu entries |
| `~/Documents/gif-capture.md` | This file |

> The command is not registered as `omarchy capture gif`. The `omarchy` CLI
> only scans `/usr/share/omarchy/bin`, which is owned by the `omarchy` package
> and overwritten on every update, so a user-level script cannot be added to
> it. Call `omarchy-capture-gif` directly, or use the shortcut.

---

## Removing it

```bash
# Remove the shortcuts (edit ~/.config/hypr/bindings.lua, then reload)
hyprctl reload

# Remove the menu entries (edit ~/.config/omarchy/extensions/omarchy-menu.jsonc)
omarchy menu refresh

# Remove the command
rm ~/.local/bin/omarchy-capture-gif

# Optionally remove the packages
sudo pacman -Rns gifsicle wf-recorder
```
