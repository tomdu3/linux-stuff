# Upwork on Arch Linux (Wayland)

## The problem

Installing `upwork-wayland` via `yay` triggered an enormous build:

```
yay -S upwork-wayland
```

`upwork-wayland` depends on `upwork`, which depends on `electron36` (the AUR
*source* package). `electron36` compiles Chromium/Electron entirely from source,
which:

- downloads ~60 GB of sources,
- pulls in dozens of build deps (`jdk`, `rustup`, `qt5-base`, `gn`, `ninja`,
  `lld`, `nodejs`, ...),
- removes your system `nodejs` and replaces it with `nodejs-lts-iron` (build
  prerequisite),
- takes many hours (sometimes 6+) to compile.

There is a prebuilt alternative: `electron36-bin`. It installs the same binary
in seconds and **provides `electron36`**, so it satisfies `upwork`'s dependency.
The build of `upwork-wayland` itself is tiny (a screenshot `.so` + wrapper).

## The fix (step by step)

### 1. Stop the source build

Interrupt the build with `Ctrl+C` in the running terminal. This is safe, even
during "Cleaning up...".

### 2. Free up the downloaded cache (~60 GB)

```bash
yay -Sc                                              # clear yay source cache
sudo rm -rf ~/.cache/yay/electron36 \
           ~/.cache/yay/upwork \
           ~/.cache/yay/upwork-wayland
```

### 3. Install the fast way

```bash
yay -S electron36-bin upwork upwork-wayland
```

- `electron36-bin` — prebuilt Electron 36 (~150 MB download, instant install).
- `upwork` — official Upwork `.deb` repackaged for Arch.
- `upwork-wayland` — small helper so screenshots work on pure Wayland
  (uses `flameshot`).

If yay asks for a provider of `electron36`, choose `electron36-bin`.

### 4. Restore your system nodejs (optional)

The failed install replaced `nodejs` with `nodejs-lts-iron`. If you want Node 26
back:

```bash
sudo pacman -S nodejs     # automatically drops nodejs-lts-iron
```

Nothing in the Upwork stack needs nodejs.

### 5. Run Upwork

Launch `upwork-wayland` from your app menu (or `upwork-wayland` in a terminal)
so screenshots work under Wayland/Hyprland.

## Gotchas

- Don't let `yay` resolve the dependency from the source `electron36` package —
  always use `electron36-bin`.
- If you ever reinstall and see it pulling `jdk`, `gn`, `ninja`, `rustup`
  again, that is the source Electron build trying to start — abort and switch
  to `electron36-bin`.