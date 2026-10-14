# Automatic Login / Unattended Boot Setup

Documentation for making this Omarchy machine boot without manual credential
entry, and for the investigation behind it.

- **Host:** `supertom`
- **OS:** Omarchy 4.0.4-1 (Arch Linux, Hyprland, kernel `7.2.5-3-omarchy`)
- **Boot:** Limine 12.8.0 + `systemd-stub` UKI
- **Root disk:** LUKS2 `/dev/sda2` → `/dev/mapper/root` (btrfs subvol `@`)
- **Config script referenced:** `/home/tom/enable-tpm-autounlock.sh`

---

## 1. TL;DR

There are **two different "logins"** at boot, and only one of them was the problem:

| Prompt | What it is | Status |
| --- | --- | --- |
| LUKS passphrase | Full-disk-encryption passphrase, entered before the kernel boots | The actual "startup login" |
| SDDM login | Graphical session login | **Already automatic** via autologin |

- **SDDM autologin is already enabled and working.** No change needed.
- To remove the **LUKS passphrase** prompt, the machine uses **Clevis + TPM2**
  to auto-unlock the disk. Omarchy has no built-in command for this.
- The passphrase is **kept** as a fallback; TPM is an *added* key, never a
  replacement.

**Result once enabled:** the machine boots straight to the desktop with no
credential entry at all. See the security warning in section 8.

---

## 2. The two prompts explained

### 2.1 SDDM graphical autologin (already working)

Display manager is SDDM:

```
/etc/systemd/system/display-manager.service -> /usr/lib/systemd/system/sddm.service
```

Autologin is configured in `/etc/sddm.conf.d/autologin.conf`:

```ini
[Autologin]
User=tom
Session=omarchy.desktop
```

The journal confirms it fires on every boot:

```
sddm-helper[925]: pam_unix(sddm-autologin:session): session opened for user tom(uid=1000)
sddm[917]: Session started true
```

Across the last 53 recorded boots, 53 opened a session for `tom` without a
password. **Nothing to do here.**

### 2.2 LUKS disk-encryption passphrase (the real issue)

The root filesystem is encrypted. `lsblk` shows:

```
sda2  221.6G  crypto_LUKS
└─root 221.6G btrfs   /home, /, /var/log, ...
```

The kernel command line unlocks it before userspace:

```
cryptdevice=PARTUUID=c0ccc12e-7bb6-4c40-99fe-2163a244d18a:root root=/dev/mapper/root ...
```

This passphrase prompt appears **before** the kernel/initramfs runs, so no
graphical setting (SDDM, autologin) can bypass it. Removing it requires
hardware-assisted unlock — the TPM.

---

## 3. How the boot chain is built

Understanding this is required before changing anything.

### 3.1 Initramfs hooks

The *effective* hooks come from the drop-in
`/etc/mkinitcpio.conf.d/omarchy_hooks.conf` (it overrides the commented
`HOOKS=` line in `/etc/mkinitcpio.conf`):

```sh
HOOKS=(base udev plymouth keyboard autodetect microcode modconf kms keymap \
       consolefont block encrypt filesystems fsck btrfs-overlayfs)
```

Plus `resume` from `/etc/mkinitcpio.conf.d/omarchy_resume.conf`.

Important: this is a **busybox (`udev`) initramfs using the classic `encrypt`
hook**, not a systemd initramfs using `sd-encrypt`.

### 3.2 UKI

Omarchy builds a Unified Kernel Image via `limine-mkinitcpio-hook`:

- `/etc/limine-entry-tool.d/omarchy-uki.conf` → `ENABLE_UKI=yes`
- `CUSTOM_UKI_NAME="omarchy"` (from `/etc/limine-entry-tool.d/omarchy-defaults.conf`)
- UKI location: `/boot/EFI/Linux/omarchy_<kernel>.efi`

### 3.3 Kernel command line

Assembled from several files, in order of precedence:

- `/etc/default/limine` → `KERNEL_CMDLINE[default]+="cryptdevice=... root=..."`
- `/etc/limine-entry-tool.d/omarchy-defaults.conf`
- `/etc/limine-entry-tool.d/omarchy-uki.conf` (resume)
- `/etc/limine-entry-tool.d/99-amdgpu-fix.conf`
- `/etc/limine-entry-tool.d/resume.conf`
- fallback: `/etc/kernel/cmdline`, then `/proc/cmdline`

### 3.4 Rebuild command

```bash
sudo limine-mkinitcpio          # rebuild all UKIs
sudo limine-mkinitcpio <kern>   # rebuild one kernel package
```

Note: `sudo mkinitcpio -P` does **nothing** here — `/etc/mkinitcpio.d/` has no
presets; the UKI build is driven by the Limine tool.

---

## 4. Why Clevis and not systemd-cryptenroll

Two community-proven methods exist; Omarchy ships neither.

| | Clevis + `mkinitcpio-clevis-hook` | systemd-cryptenroll + `sd-encrypt` |
| --- | --- | --- |
| Keeps classic `encrypt` hook | Yes | No |
| Keeps `btrfs-overlayfs` snapshot boot | Yes | **No** |
| Extra packages | `clevis`, hook | none (systemd built-in) |
| Upstream recommendation | Author now points to systemd | Preferred by upstream |

**The deciding factor:** Omarchy's snapshot/rollback boot uses
`btrfs-overlayfs`, implemented as a busybox `run_latehook`. That function only
runs under the busybox init; converting to a systemd initramfs (needed by
`sd-encrypt`) means `run_latehook` never executes and snapshot boot breaks.

Therefore **Clevis is used here** to preserve the existing, working boot chain.

Caveats accepted with this choice:

- The AUR hook (`mkinitcpio-clevis-hook 1.0-6`) was last updated 2022. Its code
  was reviewed and still matches current clevis v22: all clevis tooling lives in
  `/usr/bin/clevis*` (including `clevis-luks-common-functions`), and there is no
  `clevis-pin-tpm2` binary, so the shell TPM2 decrypt path is exactly the
  `tpm2_createprimary` / `tpm2_load` / `tpm2_unseal` / `tpm2_flushcontext` +
  `jose` set the hook bundles.
- The hook is installed manually (section 6) rather than from the AUR, avoiding
  the stale package's `tpm2-abrmd` dependency.

---

## 5. Prerequisites and pre-flight facts

Confirmed on this machine:

| Check | Result |
| --- | --- |
| Volume version | LUKS2 (required) |
| TPM device | `/dev/tpm0` and `/dev/tpmrm0` present |
| `bootctl` TPM2 support | `yes` |
| Measured UKI | `yes` (UKI is measured; good for sealing) |
| Secure Boot | **disabled (setup)** |
| `yay` | available (not needed by the script) |

---

## 6. The Clevis method — step by step

These are exactly the steps `/home/tom/enable-tpm-autounlock.sh` performs.

### Step 1 — Back up the LUKS header (safety)

```bash
sudo cryptsetup luksHeaderBackup /dev/sda2 \
     --header-backup-file /root/luks-header-backup-sda2-$(date +%Y%m%d-%H%M%S).img
sudo chmod 400 /root/luks-header-backup-sda2-*.img
```

Copy this off the machine. It is the emergency restore for the disk header.

### Step 2 — Sanity checks

```bash
cryptsetup luksDump /dev/sda2 | grep 'Version'   # must say 2
ls /dev/tpmrm0 /dev/tpm0                          # TPM must exist
```

### Step 3 — Install packages

```bash
sudo pacman -S --needed clevis tpm2-tools tpm2-tss luksmeta libpwquality jq cryptsetup
```

`jose` comes in as a clevis dependency (used by the TPM2 decrypt path).

### Step 4 — Install the mkinitcpio hook

Two files are placed under `/etc/initcpio` (mkinitcpio searches this directory
*first*):

- `/etc/initcpio/install/clevis` — build-time hook (bundles tools into the image)
- `/etc/initcpio/hooks/clevis` — runtime hook (`run_hook`, unlocks via TPM)

Source: <https://github.com/kishorviswanathan/arch-mkinitcpio-clevis-hook> (GPL-3.0).
The script embeds these verbatim.

The runtime hook reads the existing `cryptdevice=` parameter, so it needs no
kernel-cmdline changes:

```sh
IFS=: read cryptdev cryptname cryptoptions <<EOF
$cryptdevice
EOF
clevis-luks-unlock -d "$resolved" -n "$cryptname"
```

### Step 5 — Bind a TPM2 keyslot

```bash
sudo clevis luks bind -d /dev/sda2 tpm2 '{"pcr_ids":"7"}'
```

- **PCR 7** = Secure Boot state. Stable while Secure Boot remains in its current
  (disabled) state.
- This **adds** a new keyslot + LUKS2 token. Your existing passphrase slot is
  untouched.
- You will be prompted for the **existing** LUKS passphrase once.

Verify:

```bash
sudo clevis luks list -d /dev/sda2
```

### Step 6 — Enable the hook before `encrypt`

Edit `/etc/mkinitcpio.conf.d/omarchy_hooks.conf` so `clevis` precedes `encrypt`:

```sh
HOOKS=(base udev plymouth keyboard autodetect microcode modconf kms keymap \
       consolefont block clevis encrypt filesystems fsck btrfs-overlayfs)
```

`encrypt` auto-skips when `/dev/mapper/root` already exists, so the two hooks
cooperate cleanly.

### Step 7 — Rebuild the UKI

```bash
sudo limine-mkinitcpio
```

### Step 8 — Verify the UKI really contains clevis/tpm2

```bash
UKI=$(ls -1t /boot/EFI/Linux/omarchy_*.efi | head -n1)
tmp=$(mktemp /tmp/uki-initrd.XXXXXX.img)
objcopy -O binary --only-section=.initrd "$UKI" "$tmp"
lsinitcpio "$tmp" | grep -iE 'clevis|tpm2|jose'
rm -f "$tmp"
```

You should see clevis scripts and tpm2 binaries listed.

---

## 7. Running the prepared script

Everything above is wrapped in one reviewed script:

```bash
sudo bash /home/tom/enable-tpm-autounlock.sh
```

It is idempotent for the hook list (it will not add `clevis` twice) and it
backs up `omarchy_hooks.conf` before editing. Then reboot and observe whether
the passphrase prompt is gone.

The script intentionally does **not** reboot, does **not** remove any LUKS
keyslot, and does **not** touch SDDM.

---

## 8. Security implications (read this)

Enabling TPM unlock while **SDDM autologin remains enabled** means the machine
boots to the desktop with **zero authentication**:

```
power on → TPM unlocks disk → SDDM autologins → Hyprland desktop
```

Anyone with brief physical access has full access to your session and data.

Additional considerations:

- **Secure Boot is disabled.** TPM sealing with PCR 7 is far weaker without it;
  an attacker who can alter the boot path may still be able to extract the key.
- PCR-bound policy (PCR 7) will stop matching if you change Secure Boot state or
  firmware boot keys — you must rebind (section 9).
- Your **passphrase keyslot remains**, so you are never locked out; you just
  fall back to the prompt.

To restore a password gate at login (keep disk auto-unlock but require a
password to enter the desktop):

```bash
sudo mv /etc/sddm.conf.d/autologin.conf /root/autologin.conf.disabled
# (SDDM reads EVERY file in /etc/sddm.conf.d, so move it out of that directory)
```

---

## 9. Troubleshooting

### Passphrase prompt still appears after reboot

TPM unlock failed (usually PCR mismatch). You are not locked out — type your
passphrase. Then rebind:

```bash
sudo clevis luks list -d /dev/sda2          # find the clevis slot id
sudo clevis luks unbind -d /dev/sda2 -s <slot>
sudo clevis luks bind   -d /dev/sda2 tpm2 '{"pcr_ids":"7"}'
sudo limine-mkinitcpio
```

### After a firmware / Secure Boot change

Same as above — PCR 7 changed, so the policy must be recreated.

### Confirm the TPM actually unlocked (post-boot)

```bash
journalctl -b | grep -iE 'tpm|clevis'
clevis luks report -d /dev/sda2 || true
```

### The `clevis` hook is not found by mkinitcpio

Confirm the files exist and are readable:

```bash
ls -l /etc/initcpio/install/clevis /etc/initcpio/hooks/clevis
```

---

## 10. Full rollback

```bash
# 1. Remove the TPM keyslot + token
sudo clevis luks list -d /dev/sda2
sudo clevis luks unbind -d /dev/sda2 -s <slot>

# 2. Remove the hook files
sudo rm /etc/initcpio/install/clevis /etc/initcpio/hooks/clevis

# 3. Remove 'clevis' from the HOOKS line
#    /etc/mkinitcpio.conf.d/omarchy_hooks.conf   (a .bak was saved by the script)

# 4. Rebuild
sudo limine-mkinitcpio
```

Optionally remove the packages:

```bash
sudo pacman -Rns clevis tpm2-tools luksmeta libpwquality jq
```

Restore the LUKS header (only if the header itself is damaged):

```bash
sudo cryptsetup luksHeaderRestore /dev/sda2 \
     --header-backup-file /root/luks-header-backup-sda2-*.img
```

---

## 11. File reference

| Path | Purpose |
| --- | --- |
| `/etc/sddm.conf.d/autologin.conf` | SDDM autologin (already working) |
| `/etc/sddm.conf.d/10-wayland.conf`, `10-theme.conf`, `99-omarchy-login.conf` | SDDM wayland/theme/last-user config |
| `/etc/mkinitcpio.conf.d/omarchy_hooks.conf` | Effective initramfs HOOKS |
| `/etc/mkinitcpio.conf.d/omarchy_resume.conf` | Adds `resume` hook |
| `/etc/initcpio/{install,hooks}/clevis` | Installed Clevis hook (after step 4) |
| `/etc/default/limine` | `ESP_PATH`, base `KERNEL_CMDLINE[default]`, `BOOT_ORDER` |
| `/etc/limine-entry-tool.d/*.conf` | Cmdline drop-ins, `ENABLE_UKI`, `CUSTOM_UKI_NAME` |
| `/boot/EFI/Linux/omarchy_*.efi` | Built UKIs |
| `/root/luks-header-backup-*.img` | LUKS header backup |
| `/home/tom/enable-tpm-autounlock.sh` | Automation script |

---

## 12. Command quick reference

```bash
# Status
cryptsetup luksDump /dev/sda2
clevis luks list -d /dev/sda2
bootctl status                     # TPM2 Support / Measured UKI / Secure Boot
journalctl -b -u sddm              # autologin history

# Rebuild UKI
sudo limine-mkinitcpio

# Inspect the built UKI's initramfs
UKI=$(ls -1t /boot/EFI/Linux/omarchy_*.efi | head -n1)
tmp=$(mktemp); objcopy -O binary --only-section=.initrd "$UKI" "$tmp"
lsinitcpio "$tmp" | grep -iE 'clevis|tpm2|jose'; rm -f "$tmp"

# Bind / rebind / unbind TPM keyslot
sudo clevis luks bind   -d /dev/sda2 tpm2 '{"pcr_ids":"7"}'
sudo clevis luks unbind -d /dev/sda2 -s <slot>
```

---

## 13. Appendix — the automation script

The complete, reviewed script lives at `/home/tom/enable-tpm-autounlock.sh`.
It performs sections 6.1–6.8 in order, with guards:

- fails fast if not LUKS2 or no TPM
- refuses to wipe any keyslot
- saves a timestamped backup of `omarchy_hooks.conf`
- inserts `clevis` only once
- verifies the rebuilt UKI before telling you to reboot

Run it with:

```bash
sudo bash /home/tom/enable-tpm-autounlock.sh
```
