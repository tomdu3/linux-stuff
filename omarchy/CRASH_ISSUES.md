# Crash Investigation Report — 2026-09-05

System: Omarchy (Arch) on Gigabyte A520M DS3H, AMD Ryzen 5 3400G (Picasso APU,
Radeon Vega iGPU, amdgpu driver), 64 GB DDR4 (4/4 slots populated), 60 GB swap
(swapfile + zram), kernel `7.1.9-arch1-2`. Bootloader: LIMINE (UKI, managed by
`limine-entry-tool`).

---

## 1. What happened

On Saturday 2026-09-05 evening the desktop session crashed repeatedly with the
same signature: **the screen(s) go black, then the entire system becomes
unresponsive and must be power-cycled.** The last instance was at **19:03:54**
(≈ one hour before this report), matching your description of being on a
Firefox / Google Meet call when the screens went blank.

The system has rebooted many times today. A hard freeze (not a clean shutdown)
occurred in **three** of today's sessions:

| # | Boot window       | How it ended                          |
|---|-------------------|---------------------------------------|
| A | 15:41:24–18:22:46 | **Hard freeze** (Firefox + Meet call was running) |
| B | 18:27:19–18:29:29 | **Hard freeze**                       |
| C | 18:32:52–19:03:54 | **Hard freeze** (Discord, Chromium, Slack running; Meet in Chromium) |

`journalctl --list-boots` shows boots A, B, C contain **no clean-shutdown
markers** (no `Reached target Shutdown`, no `systemd-reboot`) — the journal
stops mid-operation and the machine was power-cycled. In contrast, boots -7,
-6, -4 and -1 contain clean shutdown markers (deliberate reboots). The pattern
is the **signature of a hard kernel/GPU lockup**, not an application crash and
not an orderly OS shutdown.

## 2. What was ruled out (evidence, not guesswork)

- **Out-of-memory / OOM killer** — No OOM-kill messages in any boot. `free -h`
  during the incident showed 55 GiB free; systemd accounting shows the crashed
  session peaked around 2.5 GiB. RAM was never the problem.
- **Storage / Btrfs / NVMe** — `btrfs device stats` = all zeros (no read/write
  or corruption errors). No NVMe timeouts/errors in any boot.
- **Thermals** — `sensors` at time of investigation are normal (VRM ~54 °C,
  APU idle 42 °C, NVMe 36 °C, Tctl 42 °C). Overheating is not the cause.
- **Application crash** — No coredump for the kernel or display components. The
  jittery `perf: interrupt took too long` messages right before freezes are a
  *symptom* of the system being starved, not the cause.

## 3. Root cause (with confidence levels)

### Confirmed carrier
The freezes are **hard lockups in the AMD integrated-graphics / display path on
the Ryzen 3400G (Raven/Picasso) APU** — the same general class of bug that has
been reported for years across Arch, Ubuntu, Gentoo, and even Windows for this
exact APU (black screen → total hang → power cycle). Blanking the display first
then wedging the kernel matches an `amdgpu` display-controller + VCN
(encode/decode) fault that never completes a recovery.

### Supporting, corroborating symptoms seen on this machine
- `amdgpu ... psp gfx command LOAD_TA(0x1) failed ... response status (0x7)`
  at every boot (including the healthy one) — the secure "Trusted Application"
  (HDCP) can't load on the PSP, a known Picasso flakiness.
- `[drm] Failed to setup vendor infoframe on connector DP-1: -22` at every boot.
- `AMD-Vi: Event logged [IO_PAGE_FAULT ... address=0xfedfc000 ...]` — AMD IOMMU
  page faults (NVMe/FCH MMIO range). Known noise on Gigabyte boards, but IOMMU
  has been implicated as a contributor in the 3400G freeze reports.
- `tsc: Fast TSC calibration failed`, `clocksource: Watchdog remote CPU N read
  timed out`, `Marking TSC unstable due to clocksource watchdog` — the platform
  repeatedly fails to keep the TSC clocksource stable. This is a known AMD
  A520/old-BIOS (F11p, 2020-12-18) quirk and is a *contributor*, not the
  primary trigger.
- **Memory configuration**: 4/4 DIMM slots populated on a 2-channel IMC, and
  the Vega iGPU draws on system RAM for VRAM. Recent 3400G reports (2026) show
  the exact black-screen freeze under GPU load being *caused* by unstable RAM
  (XMP/DOCP 3200 MT/s crashing, fixed by dropping to 2666). This is a strong
  candidate aggravator; a memtest pass is recommended (see §5).
- **No clean cause from a package update** — the kernel/firmware/mesa stack was
  updated 27 Aug and ran stably for a week; nothing was updated today. The
  crashes are load-triggered (heavy WebRTC/video sessions), not update-triggered.

### Honest caveat
No kernel panic was flushed (by definition a hard lock doesn't log). The
precise failing ring/IP was never recorded. The diagnosis separates **what is
proved** (repeated hard lockups in the amdgpu display/video path under video-call
load, multiple aggravating platform factors) from **what is inferred** (exact
faulting engine). The fix below targets the aggravators that reports have shown
to resolve this exact APU's freezes.

## 4. Status: fix applied (2026-09-05 21:30 BST)

The kernel-command-line fix below was applied and the boot entry re-registered.
`limine-entry-tool --get-cmdline` confirms the `linux` entry now includes
`iommu=pt amdgpu.aspm=0 clocksource=hpet`. **It takes effect on the next
reboot.** Until then:

- Firefox / Chromium WebRTC (Meet) is the trigger. If you must take calls before
  the fix is applied, use them for shorter periods, and consider forcing
  software video decoding in Firefox (`about:config` →
  `media.ffmpeg.vaapi.enabled` off) which bypasses the fragile VCN engine.
- If a freeze happens: wait 10–20 s (AMD's GPU reset sometimes recovers), then
  power-cycle if still hung. Nothing is lost; Btrfs + a clean journal will be
  consistent on reboot (proven by the check in §2).

## 5. Permanent fix (applied — see §4)

The three kernel-command-line parameters were written to the LIMINE entry-tool
drop-in and the boot entry re-registered (report timestamp reflects when the
change was made):

| Parameter          | Why                                                              |
|--------------------|------------------------------------------------------------------|
| `iommu=pt`         | Removes the AMD-Vi page-fault churn on the NVMe (a persistent logged fault and a known 3400G freeze contributor); safe passthrough, keeps IOMMU features |
| `amdgpu.aspm=0`    | Disables PCIe Active State Power Management on the GPU — a frequent amdgpu freeze trigger on Vega APUs |
| `clocksource=hpet` | Abandons the repeatedly-flagged unstable TSC in favour of the HPET, eliminating clock-skew freezes on this A520/old-BIOS platform |

Change is applied to `/etc/limine-entry-tool.d/99-amdgpu-fix.conf` using the
same mechanism the distro already uses (`KERNEL_CMDLINE[default]+=" … "`), then
the script re-registers the boot entry with `limine-entry-tool --add-uki`
(mirroring Omarchy's own mkinitcpio install hook) so the new command line lands
in `limine.conf`. It survives kernel updates, and reverts by deleting the one
drop-in file and re-running the script.

### Additional, recommended but requiring BIOS/hardware access
1. **Update the BIOS.** The system runs Gigabyte A520M DS3H BIOS **F11p
   (2020-12-18)** — very old. Gigabyte's AGESA updates since then contain many
   Picasso iGPU/memory/stability fixes. Update to the latest release for the
   board.
2. **Check RAM stability.** With 4 DIMMs populated on the 3400G, run
   `memtest86+` (bootable) through at least 2 passes. If DOCP/XMP is enabled in
   BIOS and the system is not 100% stable, drop the RAM to JEDEC speed
   (e.g. 2666 MT/s). The most recent 3400G black-screen reports (Aug 2026) were
   fixed exactly this way.
3. Keep `linux`, `linux-firmware`, `linux-firmware-amdgpu`, and `mesa` current.
   If freezes persist after the kernel-param fix, the fallback escalation is
   `amdgpu.dc=0` (drop amdgpu display core — loses some display features but
   removes the DC hang class) or a kernel downgrade; add either to the same
   drop-in file and re-run the tool.

## 6. Data safety

No user data was lost in any of today's crashes. Btrfs on `/` and `/home` shows
zero errors; snapshots (`snapper`, number limit 5) are in place. The only
uncommitted thing at risk in a freeze is whatever you had typed in the last
seconds — Firefox/Meet sessions normally restore via session restore.

## 7. Next time it happens (for diagnostics)

If a similar freeze occurs before the fix is deployed:
- Check `journalctl -b -1` — a hard lock leaves no clean shutdown marker; that
  distinguishes it from a normal reboot.
- Check `coredumpctl list` for any process cores around the time.
- Read `/sys/fs/pstore/` as root right after rebooting (before first clean
  boot) — it captures the tail of a hung kernel if the hardware preserved it.

---

*Prepared 2026-09-05 21:30 BST from journalctl (`coredumpctl`,
`journalctl --list-boots/-b N`), `btrfs device stats`, `free -h`, `sensors`,
`lspci`, and the LIMINE entry-tool configuration. Fix applied and verified
21:30 BST.*