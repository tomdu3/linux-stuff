# Upwork Desktop Time Tracker — issues on Hyprland (Wayland)

Status: **SOLUTION APPLIED** (Option 1 — Brave + Antigravity forced to X11), 2026-09-14. Undo: see `upwork-fix-undo.sh` + `Upwork_tracker_issues_undo.md`.

Related: see `UPWORK_ON_ARCH.md` for how upwork/upwork-wayland was installed.

Related: see `UPWORK_ON_ARCH.md` for how upwork/upwork-wayland was installed.

## TL;DR

- The Upwork time tracker *runs* and **screenshots work** (that part is fixed by `upwork-wayland`), but it
  **sees essentially zero keyboard/mouse activity**, so Upwork does not credit the time.
- Root cause: the tracker's activity detection is **X11-only**, and on a Wayland/Hyprland session the only X11
  (XWayland) client is Upwork itself. When you work in native-Wayland apps (Brave, foot, kitty, ...), the X server
  never receives your keystrokes/clicks, so every 10-minute segment is recorded with `keyboard=0, mouse=0` and is
  treated as idle -> not billed.
- Secondary issue: no D-Bus idle-time service exists on Hyprland, so `uta_native` logs
  `DBUS IdleTime ... The name is not activatable` on every attempt. This is a symptom of the same environment gap,
  not the direct cause of the lost minutes.

## Symptom history (reported by user)

| Day | Reported working hours | Tracked by Upwork |
|-----|------------------------|-------------------|
| 2026-09-12 (Sat) | 18:00–19:00 (60 min) | **0 min** |
| 2026-09-13 (Sun) | 18:01–19:01 (60 min) | **20 min** |

## Evidence (from `~/.Upwork/Upwork/Logs/upwork..YYYYMMDD.log`)

Session on 2026-09-13 was stopped at 19:01:45, and the app itself reported:

```
current_session_mins: 60,
today_mins: 20,
this_week_mins: 20,
```

Every ~10 minutes the shell uploads one activity log (`TRACKER_UPLOAD_STARTED`). Activity per segment:

2026-09-13 (today):
| upload time (approx) | keyboard | mouse |
|---|---|---|
| 18:02 | 1 | 1 |
| 18:18 | 3 | 1 |
| 18:23 | 0 | 0 |
| 18:39 | 0 | 0 |
| 18:44 | 0 | 0 |
| 18:59 | 0 | 0 |
| 19:01 | 0 | 1 |

2026-09-12 (yesterday): 7 uploads, **all** `keyboard=0, mouse=0`.

The only segments with activity are the two where the Upwork UI itself (an XWayland window) had focus — the
start/screenshot popups at 18:02 and 18:18. After that you were working in Wayland apps and the X server saw nothing.

Activity samples (`TRACKER_SAVE_USER_ACTIVITY`): 62 in the session, 59 with `keyboardPresses: 0, mouseClicks: 0`,
`secondsSinceLast: { input: -1, keyPress: -1, mouseClick: -1, mouseMove: -1 }` ("no input ever seen") and
`activeWindowTitle/activeProcessName: "Undefined"`.

Segments are uploaded successfully (HTTP 200), so this is **not** a connectivity/upload problem.

## Root cause

1. `uta_native.node` (Upwork's native module) detects input only through **X11 APIs** (it references the X
   "Virtual core keyboard" device, `XQueryKeymap`, `XScreenSaver*`, etc.). It cannot read Wayland input.
2. `upwork-wayland` forces the app to run as an **X11 client over XWayland** (it clears `WAYLAND_DISPLAY`,
   sets `XDG_SESSION_TYPE=x11`, `LD_PRELOAD=gdk-screenshotter.so`).
3. Under Wayland, keyboard/mouse events are only delivered to the **focused surface**. XWayland is just one more
   client: it receives input only while an XWayland window has focus. There are **no other X11 clients** on this
   box — Brave runs `--ozone-platform=wayland` (`~/.config/brave-flags.conf`), foot/kitty are Wayland-only, etc.
   So the moment you focus a native Wayland window, the tracker sees zero activity.
4. Upwork's server-side rules only credit segments that show keyboard/mouse activity ("Time without mouse or
   keyboard activity ... may not be recorded" — Upwork help). Hence 0 min / 20 min.

Verified on this machine: `xprop -root _NET_CLIENT_LIST` is empty apart from transient Upwork windows while
running — every production app is native Wayland.

Secondary: `uta_native` probes `org.gnome.ScreenSaver`, `org.gnome.Mutter.IdleMonitor`,
`org.cinnamon.ScreenSaver`, `org.freedesktop.ScreenSaver` over D-Bus for idle time. None exist on Hyprland
(`hypridle` is not installed either). Every call fails with:
`main.uta_native - DBUS IdleTime: GDBus.Error:org.freedesktop.DBus.Error.ServiceUnknown: The name is not activatable`

## upwork-wayland wrapper — checked

Installed and working for what it is designed to do (screenshots only):

```
upwork-wayland       20250925.143605-3   (AUR)
upwork               5.8.0.41-5          (AUR, repackaged .deb)
electron36-bin       36.9.5-1
flameshot            14.0.0-1            (used by the hook)
grim, jq             present             (alternative hook can use these)
```

Files:
- `/usr/bin/upwork-wayland` — wrapper; exports `UPWORK_SCREENSHOT_COMMAND="flameshot full -p"`,
  `XDG_SESSION_TYPE=x11`, `WAYLAND_DISPLAY=` (real one saved as `WAYLAND_DISPLAY_REAL`),
  `LD_PRELOAD=/usr/lib/upwork-wayland/gdk-screenshotter.so`, then execs `upwork`.
- `/usr/lib/upwork-wayland/gdk-screenshotter.so` — intercepts `gdk_pixbuf_get_from_window()` so the app captures
  the real desktop via flameshot instead of a grey "Wayland not supported" image.
- `/usr/share/applications/upwork-wayland.desktop` → `Exec=/usr/bin/upwork-wayland %U`.

Evidence it works: on 2026-09-13 the screenshots succeeded (`Electron Screensnap succeeded.`), screenshots were
taken ~every 10 min (18:02, 18:18, 18:23, ...), and the uploads carried a real 1920x515 PNG (~799 KB). So **the
screenshot side is fine; the missing time is purely the activity-detection side.**

Caveat: the AUR hook uses `flameshot full -p`. A maintained Hyprland-specific alternative
(`niiithish/upwork-wayland-hyprland`) replaces flameshot with `grim` + `hyprctl activewindow` for the window
title; `grim` and `jq` are already installed here, so that fork is a drop-in fallback if flameshot ever breaks.
Not needed right now.

## Applied fix (2026-09-14) — the current state of the system

Brave and Antigravity IDE are forced to X11 via their per-app flags files so the X server
sees your input while you work in them:

- `~/.config/brave-flags.conf` → `--ozone-platform=x11` / `--ozone-platform-hint=x11` (the `wayland` values were changed to `x11`; all other flags untouched)
- `~/.config/antigravity-ide-flags.conf` → **created** with `--ozone-platform=x11` / `--ozone-platform-hint=x11` (launcher reads it automatically, same mechanism as Brave)

Everything else stays native Wayland: Discord, foot, kitty, and the Upwork app itself (XWayland via `upwork-wayland`).

Verified:
- Both apps relaunched and appear as **XWayland clients** (`xprop -root _NET_CLIENT_LIST` → Brave-browser + Antigravity IDE).
- Expected daily-use consequences of having only these two apps on X11:

| Impact | Note |
|---|---|
| Text crispness @ monitor scale 1.25 | Was NOT affected in practice — leave as-is unless text looks soft; only then consider the `--force-device-scale-factor` option below. |
| File dialogs (Brave/IDE) | Now the X11 GTK picker, not the portal one. Cosmetic. |
| Middle-click paste & DnD across Wayland↔X11 | Works inside the X11 pair (Brave↔IDE) and inside Wayland apps; does **not** cross the boundary. Ctrl+C/V copy/paste works everywhere. |
| Screen sharing from Brave/IDE | Portal-based sharing gone; Discord (Wayland) is unaffected. |
| Password manager | `gnome-libsecret` unaffected (D-Bus based). |
| Tiling / rules / keybindings / extensions | Identical under Hyprland. |

If text later looks soft at 1.25 in the X11 apps, the known fix is adding
`--force-device-scale-factor=1.25` to both flag files, optionally with
`xwayland { force_zero_scaling = true }` in `hyprland.conf`. Not applied — not needed yet.

Undo (back to native Wayland): run `~/Work/upwork-fix-undo.sh` — the script restores the
Wayland flags, removes `antigravity-ide-flags.conf`, and restarts both apps. See
`Upwork_tracker_issues_undo.md` for details.

Tracking-log verification is **pending the next tracking session** (Upwork wasn't running
when the change was made). The structural condition is already proven — both apps are now
real XWayland clients — so the tracker will see keyboard/mouse input whenever they are
focused. Confirm with the checklist in "Verification after applying a fix" below.

---

## Solutions

### 1. Do your working in X11/XWayland windows (recommended, honest)

Make the app you are actively working in a client of the same X server as Upwork, so the X server sees your input
while it has focus:

- Brave: edit `~/.config/brave-flags.conf`:
  ```
  --ozone-platform=x11
  --ozone-platform-hint=x11
  # optional, keeps text crisp on the 1.25-scale displays:
  --force-device-scale-factor=1.25
  ```
  then fully quit and relaunch Brave.
- Antigravity IDE (Electron/VS Code fork): launch with `--ozone-platform=x11`.
- Terminals: foot/kitty can be forced to X11 via `GDK_BACKEND=x11` / `QT_QPA_PLATFORM=xcb` as appropriate.

Trade-off: those apps lose native-Wayland rendering for the duration (may need `--force-device-scale-factor`
for HiDPI). Nothing else on the desktop changes.

### 2. Synthetic "keepalive" pointer nudge via XTest (alternative, verified, use at your own discretion)

If you want to stay fully Wayland-native, a small helper can periodically inject a tiny pointer move directly into
the X server (XTest). Because it is injected server-side, Upwork sees the motion even when every XWayland window
is unfocused.

Verified on this machine (2026-09-14):
```
xtest query ok=1 ... maj=2 min=2        # XTest available on the XWayland display
injected to (501,400)                   # XTestFakeMotionEvent
t=09 X= 501 Y= 400                      # XQueryPointer in another client now reports it
```

Mechanics: XTest works on this XWayland, and `XQueryPointer` (which the tracker uses) observes the injected
motion. A tool such as `xdotool mousemove_relative -- 1 1` (or a tiny C helper) run every 30–60 s while tracking
would make every segment non-empty.

**Fair warning:** Upwork/vara client-side "fake activity" can look like time fraud and may be flagged or rejected.
Only consider this if option 1 is impractical, and prefer the real input of option 1.

### 3. D-Bus idle-time provider (hygiene fix — does NOT by itself restore lost minutes)

`uta_native` expects one of the GNOME/Cinnamon/freedesktop ScreenSaver D-Bus interfaces. Nothing on Hyprland
provides it (`swayidle`/`hypridle` do not; both only talk Wayland idle-notify). You would have to run a tiny
custom D-Bus daemon exporting e.g. `org.freedesktop.ScreenSaver.GetSessionIdleTime() -> 0`.

This would silence the `DBUS IdleTime` errors and improve app behaviour overall, but the lost minutes are driven
by the `keyboard`/`mouse` counters (X-based), not by the idle-time value — so by itself it will not credit the
empty segments. Treat it as a supplement, not a fix.

### 4. Manual time (immediate fallback)

For segments already lost, the only supported route is in-app **Add manual time** (needs client approval; not
covered by Hourly Payment Protection). Useful while you sort out option 1 or 2.

## Verification after applying a fix

1. Start tracking and actually work in your tracked app for at least 10–15 minutes.
2. Check the newest log:
   ```
   grep -A20 '"type": "TRACKER_UPLOAD_STARTED"' ~/.Upwork/Upwork/Logs/upwork..$(date +%Y%m%d).log
   ```
   The `keyboard:` / `mouse:` fields for each segment must be non-zero.
3. Confirm in the Work Diary that the segments show a green activity bar and that Today reflects the time.

## Notes / gotchas

- Don't uninstall `upwork-wayland` — screenshots break on Wayland without it (grey placeholder image, or the app
  complaining "Upwork Screenshots are not supported on Wayland").
- If the tracker still shows idle after switching an app to X11, that app must be **relaunched** so it actually
  becomes an XWayland client.
- Upwork's own Linux guidance is "use Xorg"; this repo documents how to keep Hyprland instead.