# Undoing the "force X11" Upwork time-tracker fix

Script: `./upwork-fix-undo.sh`
Date created: 2026-09-14

## What this un-does

To make the Upwork tracker see your typing/clicking, Brave and Antigravity IDE were
forced to run under X11/XWayland instead of native Wayland:

| File | Change made |
|---|---|
| `~/.config/brave-flags.conf` | `--ozone-platform=wayland` + `--ozone-platform-hint=wayland` were replaced with `x11` |
| `~/.config/antigravity-ide-flags.conf` | **Created** containing `--ozone-platform=x11` / `--ozone-platform-hint=x11` (did not exist before) |

Native Wayland was (and is) the default for both apps, so "undoing" means putting them
back to their prior, Wayland state.

## How to undo (manual)

### 1. Brave

`~/.config/brave-flags.conf` — set the first two lines back to:

```
--ozone-platform=wayland
--ozone-platform-hint=wayland
```

(Keep all other lines unchanged — passwords, extensions, etc. are unrelated to this fix.)

### 2. Antigravity IDE

Delete `~/.config/antigravity-ide-flags.conf`. The launcher `/usr/bin/antigravity-ide`
only reads it if it exists, so with the file gone the IDE runs in its default Wayland mode.

### 3. Restart the apps

Both apps must be **fully quit and relaunched** for the change to take effect —
changing the flag file does not affect an already-running instance.

## Using the provided script

```sh
cd ~/Work
./upwork-fix-undo.sh
```

The script does exactly the three steps above (idempotent — safe to run multiple
times). It does **not** touch anything else (no `hyprland.conf` changes, no Upwork
files, no other apps).

## When to undo

- Choose **native Wayland rendering** over Upwork time tracking (e.g. you prefer the
  smoother scroll / portal dialogs and accept tracking fewer minutes — see
  `Upwork_tracker_issues.md` for the tradeoffs).
- X11 rendering of either app breaks (blurry text, scaling issues, crashes).
- You later find a different solution (e.g. the XTest keepalive from `Upwork_tracker_issues.md`
  tier 2) and no longer need the apps on X11.

## After undoing — check

If you undo and the tracker obviously logs 0 minutes again, that is expected: it will
show exactly the behaviour documented in `Upwork_tracker_issues.md` (the X11 apps were
the only reason it worked). Note that only the **keyboard/mouse** detecting changes;
the screenshot side (`upwork-wayland` wrapper) is untouched by both the fix and the undo.