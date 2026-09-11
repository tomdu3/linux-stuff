# Terminal Font Fix

## The Situation

Until 2026-09-11, all four installed terminals were configured with
**JetBrainsMono Nerd Font** at size 9:

| Terminal | Config file |
|----------|-------------|
| Alacritty | `~/.config/alacritty/alacritty.toml` |
| Foot | `~/.config/foot/foot.ini` |
| Kitty | `~/.config/kitty/kitty.conf` |
| Ghostty | `~/.config/ghostty/config` |

The system only had a handful of fonts installed (JetBrainsMono Nerd Font,
iA Writer Mono S, Adwaita Mono, Liberation Mono, Nimbus Mono PS), so the
options exposed by `omarchy font list` were all generic system fonts rather
than proper terminal/coding fonts.

## Suggested Fonts

Arch (Extra repo) ships 65+ nerd-font packages. The best monospace upgrades
over JetBrains Mono:

| Font | Package | Why it's good |
|------|---------|---------------|
| Fira Code | `ttf-firacode-nerd` | De-facto standard for coding; excellent ligatures, zero ambiguity |
| Cascadia Code | `ttf-cascadia-code-nerd` | Windows Terminal's font; great readability plus playful ligatures |
| Meslo | `ttf-meslo-nerd` | Powerline classic; very close to the JetBrains Mono feel |
| Iosevka | `ttf-iosevka-nerd` | Slim/condensed; packs more characters per line |
| **Monaspace (chosen)** | `otf-monaspace-nerd` | GitHub's modern family; 5 sub-styles (Argon, Krypton, Neon, Radon, Xenon) |

Fonts can be browsed with `pacman -S ttf-...` auto-completion or by searching
`pacman -Ss nerd` (filter for `-mono-` / `-nerd` packages).

## What Was Changed

1. **Installed the font package** (root):

   ```
   pkexec pacman -S --noconfirm --needed otf-monaspace-nerd
   ```

   The package installs into `/usr/share/fonts/OTF/` as five sub-families
   (Argon/`Ar`, Krypton/`Kr`, Neon/`Ne`, Radon/`Rn`, Xenon/`Xe`).

2. **Refreshed fontconfig cache** and confirmed the family names:

   ```
   fc-cache -f
   fc-list : family | grep -i monaspice
   ```

   Note: recent Monaspace releases renamed the family to **"Monaspice"**, so
   the family is *not* `Monaspace ...` in `fc-list`.

3. **Set the font system-wide with the omarchy CLI**:

   ```
   omarchy font set "MonaspiceNe Nerd Font Mono"
   ```

   What this command did (per `/usr/bin/omarchy-font-set`):
   - Updated `family` in `~/.config/alacritty/alacritty.toml` (normal/bold/italic)
   - Updated `font_family` in `~/.config/kitty/kitty.conf` and signalled running kitties (`pkill -USR1 kitty`)
   - Updated `font-family` in `~/.config/ghostty/config` and signalled ghostty (`pkill -SIGUSR2 ghostty`)
   - Updated `font=` in `~/.config/foot/foot.ini`
   - Prepended the font to the `monospace` family in fontconfig
   - Restarted the omarchy shell

4. **Applied to running terminals**:

   ```
   omarchy restart terminal
   ```

   Note: Foot only picks font changes up in *new* windows.

## Resulting Font

**MonaspiceNe Nerd Font Mono** (Monaspace's flagship Neon style, mono variant)
at **size 9** in all four terminals. The `Mono` variant must be used — the base
`MonaspiceNe Nerd Font` is the proportional variant and is not right for a
terminal.

## Changing the Font in the Future

Any installed font can be selected:

```
# List what omarchy knows about / is currently set to
omarchy font list
omarchy font current

# If the font is not installed yet (root prompt required):
pkexec pacman -S --noconfirm --needed <package>   # e.g. ttf-ibmplex-mono-nerd

# Refresh fontconfig so the family shows up
fc-cache -f

# Apply it (family name as shown by: fc-list : family | grep -i <name>)
omarchy font set "Family Name Nerd Font Mono"

# Reload running terminals
omarchy restart terminal
```

Tips:

- Always use the **Mono** / monospaced variant of a nerd font family
  (`fc-list` output ending in `Nerd Font Mono` / `NFM`).
- Use the exact family string from `fc-list`; `omarchy font set` warns/fails
  if the font isn't found.
- Font size lives separately in each terminal config (currently 9); edit
  `size = 9` (alacritty), `:size=9` (foot), `font_size 9.0` (kitty),
  `font-size = 9` (ghostty) to change it.
- Terminal configs can always be reset with `omarchy refresh <app>`.