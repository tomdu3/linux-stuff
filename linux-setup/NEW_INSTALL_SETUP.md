# Fresh Linux Setup & Migration Guide (`NEW_INSTALL_SETUP.md`)

This guide documents the complete post-install setup and configuration migration process for this Linux environment. Use these steps whenever setting up a new machine or restoring configurations from backup.

---

## 1. System Prerequisites & Essential Packages

Install standard build tools, shell utilities, and SSHFS:

```bash
sudo apt update && sudo apt install -y \
  build-essential \
  curl \
  wget \
  git \
  tmux \
  zsh \
  sshfs \
  fuse3 \
  libfuse2t64 \
  libpam-umask \
  bash-completion \
  xclip \
  wl-clipboard
```

---

## 2. SSH Configuration & Key Permissions

When restoring `.ssh` from a backup or another machine, OpenSSH requires strict file permissions to function without warnings or connection rejections.

### Directory Structure & Required Permissions

| Path                                               | Type      | Permissions  | Octal |
| :------------------------------------------------- | :-------- | :----------- | :---- |
| `~/.ssh/`                                          | Directory | `drwx------` | `700` |
| `~/.ssh/config`                                    | File      | `-rw-------` | `600` |
| `~/.ssh/authorized_keys`                           | File      | `-rw-------` | `600` |
| `~/.ssh/known_hosts` / `known_hosts.old`           | File      | `-rw-------` | `600` |
| `~/.ssh/*_rsa`, `~/.ssh/*_ed25519*` (Private keys) | Files     | `-rw-------` | `600` |
| `~/.ssh/*.pub` (Public keys)                       | Files     | `-rw-r--r--` | `644` |
| `~/.sshfs/`                                        | Mount Dir | `drwxr-xr-x` | `755` |

### One-Click Permission Fix Command

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/config ~/.ssh/authorized_keys ~/.ssh/known_hosts* 2>/dev/null || true
chmod 600 ~/.ssh/id_rsa ~/.ssh/id_ed25519_* ~/.ssh/contabo_rsa 2>/dev/null || true
chmod 644 ~/.ssh/*.pub 2>/dev/null || true
chmod 755 ~/.sshfs 2>/dev/null || true
```

### SSH Config Reference (`~/.ssh/config`)

```ssh-config
# Homelab Server Configuration
Host homelab
    HostName 192.168.0.50
    User tom
    IdentityFile ~/.ssh/id_ed25519_hl
    # Port Forwarding for Development
    LocalForward 3000 127.0.0.1:3000
    # Port for FastAPI / Python Backend
    LocalForward 8000 127.0.0.1:8000
    # Port for Portainer Dashboard
    LocalForward 9000 127.0.0.1:9000

# DigitalOcean Cloud VM
Host digitalocean
    IdentityFile ~/.ssh/id_ed25519_digitalocean

# Contabo VPS
Host contabo
    IdentityFile ~/.ssh/contabo_rsa
```

---

## 3. SSHFS Remote Mount Workflow

SSHFS enables transparent local editing of files hosted on remote servers (such as `homelab`).

### Mount & Unmount Commands

- **Mount**:

  ```bash
  mkdir -p ~/remote-projects/homelab
  sshfs homelab: ~/remote-projects/homelab
  ```

- **Unmount**:

  ```bash
  fusermount -u ~/remote-projects/homelab
  ```

### Shell Helpers (Built into `.bashrc`)

- Run `mount-lab` in your terminal to automatically create the folder and mount the remote homelab.
- Run `unmount-lab` to safely detach the mount.

---

## 4. Shell Integration (`.bashrc`)

The consolidated `.bashrc` contains interactive shell features, aliases, environment paths, API keys, and mount helpers:

```bash
# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History control
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000

# Window sizing & pager helpers
shopt -s checkwinsize
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Debian chroot
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# Color prompt support
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt

# Color support for ls & handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Quick navigation aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ag='antigravity-ide'
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Include external aliases if present
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Programmable completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# User binary PATHs
export PATH="$HOME/.local/bin:$PATH"

if [ -d "/opt/nvim-linux-x86_64/bin" ]; then
    export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
fi

# Language & Tool Environments
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin"
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# Android SDK
if [ -d "$HOME/Android/Sdk" ]; then
    export ANDROID_HOME="$HOME/Android/Sdk"
    export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin"
fi

# API Keys
export GEMINI_API_KEY=GEMINI_API_KEY
export NVIDIA_API_KEY=nvapi-nvidia-api-key

# SSHFS Mount Helpers
mount-lab() {
    mkdir -p "$HOME/remote-projects/homelab"
    if command -v sshfs >/dev/null 2>&1; then
        sshfs homelab: "$HOME/remote-projects/homelab" && echo "Mounted homelab to ~/remote-projects/homelab"
    else
        echo "sshfs is not installed. Run: sudo apt update && sudo apt install sshfs"
    fi
}

unmount-lab() {
    fusermount -u "$HOME/remote-projects/homelab" 2>/dev/null || umount "$HOME/remote-projects/homelab" 2>/dev/null && echo "Unmounted homelab"
}
```

---

## 5. Development Toolchains & Languages

### 1. Rust (`rustc`, `cargo`, `rustup`)

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
rustc --version && cargo --version
```

### 2. Astral UV (`uv`, `uvx`)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
uv --version
```

### 3. Node.js & npm (LTS)

```bash
mkdir -p ~/.local/node
curl -fsSL https://nodejs.org/dist/v24.19.0/node-v24.19.0-linux-x64.tar.xz | tar -xJ -C ~/.local/node --strip-components=1
ln -sf ~/.local/node/bin/node ~/.local/bin/node
ln -sf ~/.local/node/bin/npm ~/.local/bin/npm
ln -sf ~/.local/node/bin/npx ~/.local/bin/npx
node --version && npm --version
```

### 4. Golang (`go`, `gofmt`)

```bash
mkdir -p ~/.local/go ~/go/bin
curl -fsSL https://go.dev/dl/go1.27.0.linux-amd64.tar.gz | tar -xz -C ~/.local/go --strip-components=1
ln -sf ~/.local/go/bin/go ~/.local/bin/go
ln -sf ~/.local/go/bin/gofmt ~/.local/bin/gofmt
go version
```

### 5. Lua 5.4 (`lua`, `luac`)

```bash
cd /tmp
curl -fsSL https://www.lua.org/ftp/lua-5.4.7.tar.gz | tar -xz
make -C lua-5.4.7 all
make -C lua-5.4.7 INSTALL_TOP=$HOME/.local install
rm -rf /tmp/lua-5.4.7
lua -v
```

### 6. fzf (Command-line Fuzzy Finder)

```bash
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install --all
ln -sf ~/.fzf/bin/fzf ~/.local/bin/fzf
fzf --version
```

---

## 6. Applications & Binaries Setup

### Antigravity IDE

Extract `Antigravity IDE.tar.gz` to `~/.local/share/antigravity-ide/` and create launchers:

```bash
# 1. Extract archive
mkdir -p ~/.local/share/antigravity-ide
tar -xzf "Antigravity IDE.tar.gz" -C ~/.local/share/antigravity-ide --strip-components=1

# 2. Create binary symlinks
mkdir -p ~/.local/bin
ln -sf ~/.local/share/antigravity-ide/bin/antigravity-ide ~/.local/bin/antigravity-ide
ln -sf ~/.local/share/antigravity-ide/bin/antigravity-ide ~/.local/bin/ag

# 3. Create desktop launcher (~/.local/share/applications/antigravity-ide.desktop)
cat << 'EOF' > ~/.local/share/applications/antigravity-ide.desktop
[Desktop Entry]
Name=Antigravity IDE
Comment=Code Editing with Antigravity
GenericName=Text Editor
Exec=/home/tom/.local/bin/antigravity-ide %F
Icon=/home/tom/.local/share/antigravity-ide/resources/app/resources/linux/code.png
Type=Application
StartupNotify=false
StartupWMClass=Antigravity IDE
Categories=TextEditor;Development;IDE;
MimeType=text/plain;inode/directory;
Keywords=vscode;antigravity;ide;editor;development;
EOF
```

### Antigravity CLI (`agy`)

Ensure `agy` executable is in `~/.local/bin/`:

```bash
mkdir -p ~/.local/bin
chmod +x ~/.local/bin/agy
agy --version
```

### Neovim (v0.10+ / Linux x86_64)

Extract Neovim tarball directly into `/opt/`:

```bash
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
/opt/nvim-linux-x86_64/bin/nvim --version
```

### Nerd Fonts (JetBrainsMono & FiraCode)

Install the primary coding fonts with full developer glyphs and devicons:

```bash
mkdir -p ~/.local/share/fonts/NerdFonts /tmp/nerdfonts
cd /tmp/nerdfonts
curl -fsSLO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.0/JetBrainsMono.tar.xz
curl -fsSLO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.0/NerdFontsSymbolsOnly.tar.xz
curl -fsSLO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.0/FiraCode.tar.xz

tar -xJf JetBrainsMono.tar.xz -C ~/.local/share/fonts/NerdFonts/
tar -xJf NerdFontsSymbolsOnly.tar.xz -C ~/.local/share/fonts/NerdFonts/
tar -xJf FiraCode.tar.xz -C ~/.local/share/fonts/NerdFonts/
rm -rf /tmp/nerdfonts

fc-cache -fv ~/.local/share/fonts
```

### Terminal Configurations

#### 1. Kitty Terminal (`~/.config/kitty/kitty.conf`)

```conf
font_family      family="JetBrainsMono Nerd Font"
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        13.0
```

#### 2. Default GNOME Terminal / Ptyxis

Set the system-wide monospace font to JetBrainsMono Nerd Font:

```bash
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11'
```

### Docker & Docker Compose

Install container engine and multi-container orchestration:

```bash
snap install docker
ln -sf /snap/bin/docker.compose ~/.local/bin/docker-compose 2>/dev/null || true

# Enable non-root docker usage:
sudo addgroup --system docker 2>/dev/null || true
sudo usermod -aG docker $USER

# To apply immediately without logging out, either:
# Option A: Install util-linux-extra and run newgrp
sudo apt install -y util-linux-extra && newgrp docker
# Option B: Or simply log out and back into Ubuntu
```

### Web Browsers (Chrome, Vivaldi, Brave, Zen, Floorp)

Install all primary browsers:

```bash
# 1. Brave & Vivaldi (via Snap)
snap install brave vivaldi
ln -sf /snap/bin/vivaldi.vivaldi-stable ~/.local/bin/vivaldi 2>/dev/null || true

# 2. Google Chrome (Debian package extraction)
curl -fsSLO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
dpkg-deb -x google-chrome-stable_current_amd64.deb /tmp/chrome_pkg
mkdir -p ~/.local/share/google-chrome
cp -r /tmp/chrome_pkg/opt/google/chrome/* ~/.local/share/google-chrome/
ln -sf ~/.local/share/google-chrome/google-chrome ~/.local/bin/google-chrome
rm -rf /tmp/chrome_pkg google-chrome-stable_current_amd64.deb

# 3. Zen Browser (Official GitHub release)
mkdir -p ~/.local/share/zen-browser
curl -fsSL https://github.com/zen-browser/desktop/releases/download/1.21.15b/zen.linux-x86_64.tar.xz | tar -xJ -C ~/.local/share/zen-browser --strip-components=1
ln -sf ~/.local/share/zen-browser/zen ~/.local/bin/zen

# 4. Floorp (Official GitHub release)
mkdir -p ~/.local/share/floorp
curl -fsSL https://github.com/Floorp-Projects/Floorp/releases/download/v12.16.4/floorp-linux-x86_64.tar.xz | tar -xJ -C ~/.local/share/floorp --strip-components=1
ln -sf ~/.local/share/floorp/floorp ~/.local/bin/floorp

# 5. Opera & Proprietary Video/Audio Codecs Fix
snap install opera chromium-ffmpeg
ln -sf /snap/bin/opera ~/.local/bin/opera
```

### Communication Apps (Slack & Discord)

Install team chat and community tools:

```bash
snap install slack
snap install discord
```

### Oh-My-Zsh (Optional / Zsh Users)

When using Zsh, ensure the standard plugin suite is installed:

```bash
# Clone plugins if missing:
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
```

---

## 7. Quick Post-Install Checklist

- [ ] Run `sudo apt update && sudo apt install -y sshfs git build-essential`
- [ ] Restore `~/.ssh/` keys and copy `~/.ssh/config`
- [ ] Run the SSH permission fixer commands
- [ ] Install Nerd Fonts (JetBrainsMono, FiraCode) & run `fc-cache -fv`
- [ ] Configure Kitty & GNOME Terminal monospace font
- [ ] Install Rust via `rustup` (`rustc`, `cargo`)
- [ ] Install Astral UV (`uv`, `uvx`)
- [ ] Install Node.js LTS (`node`, `npm`)
- [ ] Install Golang (`go`, `gofmt`)
- [ ] Build & install Lua 5.4 (`lua`, `luac`)
- [ ] Install fzf (`fzf`, keybindings)
- [ ] Install Docker & Docker Compose (`snap install docker`)
- [ ] Add user to docker group (`sudo usermod -aG docker $USER`)
- [ ] Install Web Browsers (Chrome, Vivaldi, Brave, Zen Browser, Floorp, Opera + Codecs)
- [ ] Install Antigravity IDE to `~/.local/share/antigravity-ide/` and verify `ag --version`
- [ ] Install Slack & Discord via Snap (`snap install slack discord`)
- [ ] Extract Neovim to `/opt/nvim-linux-x86_64/`
- [ ] Place `agy` in `~/.local/bin/`
- [ ] Update `~/.bashrc` (or `~/.zshrc`) and run `source ~/.bashrc`
- [ ] Test SSH connection: `ssh homelab`
- [ ] Test SSHFS mount: `mount-lab`
