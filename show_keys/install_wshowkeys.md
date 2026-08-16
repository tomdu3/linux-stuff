# `wshowkeys` (Minimalist CLI Wayland Overlay)

`wshowkeys` is a lightweight, zero-bloat CLI keycaster built specifically for Wayland. It renders key combinations directly onto your screen edge using Cairo/Pango without full desktop window borders.

GitHub

**1. Install build dependencies:**

Bash

```
sudo apt update
sudo apt install -y libcairo2-dev libpango1.0-dev libudev-dev libinput-dev \
  libxkbcommon-dev libwayland-dev wayland-protocols meson ninja-build
```

**2. Clone and build:**

Bash

```
git clone https://github.com/DreamMaoMao/wshowkeys.git
cd wshowkeys
meson setup build
ninja -C build
sudo ninja -C build install
# Grant input reading permission (required for Wayland key capture)
sudo chmod a+s /usr/local/bin/wshowkeys
```

**3. Run:**

Bash

```Bash
# Display keys anchored to bottom center with a 1-second fade timeout
wshowkeys -a bottom -t 1000 -F 'Sans Bold 28' -b '#1e1e2ecc' -f '#cdd6f4ff'
```

```Bash
wshowkeys -a bottom -F 'Sans Bold 30' -s '#B5B520ff' -f  '#ecd29cff' -b '#201B1488' -l 600 -t 500 -M -U -S
```


