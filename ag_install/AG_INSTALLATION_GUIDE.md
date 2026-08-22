# Antigravity IDE 2.0 Installation Guide (Linux)

This guide provides step-by-step instructions for performing a clean, non-root user installation of **Antigravity IDE 2.0** on Linux from the standalone tarball archive (`Antigravity IDE.tar.gz`).

---

## 1. Directory Structure Overview

The installation uses standard XDG user directory locations:

| Component | Path | Description |
| :--- | :--- | :--- |
| **Application Directory** | `~/.local/share/antigravity-ide/` | Extracted app files, binaries, runtime resources |
| **CLI Binaries & Symlinks** | `~/.local/bin/antigravity-ide`<br>`~/.local/bin/ag`<br>`~/.local/bin/agy-ide` | Executable symlinks accessible via `$PATH` |
| **Desktop Launcher** | `~/.local/share/applications/antigravity-ide.desktop` | Application menu & launcher entry |
| **App Icons** | `~/.local/share/icons/hicolor/1024x1024/apps/antigravity-ide.png`<br>`~/.local/share/pixmaps/antigravity-ide.png` | Standard XDG icons |
| **Shell Completions** | `~/.local/share/bash-completion/completions/`<br>`~/.local/share/zsh/site-functions/` | Bash and Zsh tab autocompletion scripts |

---

## 2. Step-by-Step Installation

### Step 1: Extract the Tarball

Create the destination directory and extract the archive:

```bash
# Create the application directory
mkdir -p ~/.local/share/antigravity-ide

# Extract the archive (stripping the root folder inside the tarball)
tar -zxf "Antigravity IDE.tar.gz" -C ~/.local/share/antigravity-ide --strip-components=1
```

---

### Step 2: Set Up CLI Symlinks

Ensure `~/.local/bin` exists and create symlinks for the main binary and aliases (`antigravity-ide`, `ag`, `agy-ide`):

```bash
# Ensure ~/.local/bin exists
mkdir -p ~/.local/bin

# Symlink the launcher scripts
ln -sf ~/.local/share/antigravity-ide/bin/antigravity-ide ~/.local/bin/antigravity-ide
ln -sf ~/.local/share/antigravity-ide/bin/antigravity-ide ~/.local/bin/agy-ide
ln -sf ~/.local/share/antigravity-ide/bin/antigravity-ide ~/.local/bin/ag
```

---

### Step 3: Verify PATH & Configure Shell Aliases

Make sure `~/.local/bin` is in your `PATH` and optionally add shell aliases to your configuration files.

#### For Bash (`~/.bashrc`):
```bash
# Add ~/.local/bin to PATH if not already present
export PATH="$HOME/.local/bin:$PATH"

# Antigravity IDE alias
alias ag="antigravity-ide"
```

#### For Zsh (`~/.zshrc`):
```zsh
# Add ~/.local/bin to PATH if not already present
export PATH="$HOME/.local/bin:$PATH"

# Antigravity IDE alias
alias ag="antigravity-ide"
```

---

### Step 4: Install Application Icons

Copy the application icon to the standard XDG icon directories:

```bash
mkdir -p ~/.local/share/icons/hicolor/1024x1024/apps ~/.local/share/pixmaps

cp ~/.local/share/antigravity-ide/resources/app/resources/linux/code.png \
   ~/.local/share/icons/hicolor/1024x1024/apps/antigravity-ide.png

cp ~/.local/share/antigravity-ide/resources/app/resources/linux/code.png \
   ~/.local/share/pixmaps/antigravity-ide.png
```

---

### Step 5: Create the Desktop Entry

Create the `.desktop` file so the application appears in your desktop application launcher (e.g., COSMIC, GNOME, KDE, Rofi):

```bash
cat << 'EOF' > ~/.local/share/applications/antigravity-ide.desktop
[Desktop Entry]
Name=Antigravity IDE
Comment=AI-First Integrated Development Environment
GenericName=Text Editor
Exec=/home/tom/.local/share/antigravity-ide/bin/antigravity-ide %F
Icon=antigravity-ide
Type=Application
StartupNotify=false
StartupWMClass=Antigravity IDE
Categories=Development;IDE;
MimeType=text/plain;inode/directory;application/x-code-workspace;
Actions=new-empty-window;
Keywords=antigravity;antigravity-ide;ide;code;editor;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=/home/tom/.local/share/antigravity-ide/bin/antigravity-ide --new-window %F
Icon=antigravity-ide
EOF
```

Update the desktop database and icon cache:

```bash
update-desktop-database ~/.local/share/applications || true
gtk-update-icon-cache ~/.local/share/icons/hicolor 2>/dev/null || true
```

---

### Step 6: Configure Shell Autocompletions

Install the bundled Bash and Zsh completion scripts:

```bash
# Bash completions
mkdir -p ~/.local/share/bash-completion/completions
cp ~/.local/share/antigravity-ide/resources/completions/bash/antigravity-ide ~/.local/share/bash-completion/completions/antigravity-ide

# Enable completion for ag and agy-ide
echo "complete -F _antigravity-ide ag" >> ~/.local/share/bash-completion/completions/antigravity-ide
echo "complete -F _antigravity-ide agy-ide" >> ~/.local/share/bash-completion/completions/antigravity-ide
ln -sf ~/.local/share/bash-completion/completions/antigravity-ide ~/.local/share/bash-completion/completions/ag
ln -sf ~/.local/share/bash-completion/completions/antigravity-ide ~/.local/share/bash-completion/completions/agy-ide

# Zsh completions
mkdir -p ~/.local/share/zsh/site-functions
cp ~/.local/share/antigravity-ide/resources/completions/zsh/_antigravity-ide ~/.local/share/zsh/site-functions/_antigravity-ide
```

---

## 3. Verification

Verify the installation by running the following commands in your terminal:

```bash
# Check version output
antigravity-ide --version
ag --version

# Open current directory in the IDE
ag .
```

---

## 4. Uninstallation / Clean Up

To remove Antigravity IDE and its associated configurations, run:

```bash
rm -rf ~/.local/share/antigravity-ide
rm -f ~/.local/bin/antigravity-ide ~/.local/bin/agy-ide ~/.local/bin/ag
rm -f ~/.local/share/applications/antigravity-ide.desktop
rm -f ~/.local/share/icons/hicolor/1024x1024/apps/antigravity-ide.png ~/.local/share/pixmaps/antigravity-ide.png
rm -f ~/.local/share/bash-completion/completions/antigravity-ide ~/.local/share/bash-completion/completions/ag ~/.local/share/bash-completion/completions/agy-ide
rm -f ~/.local/share/zsh/site-functions/_antigravity-ide
update-desktop-database ~/.local/share/applications || true
```

---

## 5. Known Issues & Troubleshooting

### Issue: IDE Fails to Launch on Ubuntu 24.04+ / 26.04+ (AppArmor / SUID Sandbox Error)

#### Symptoms
Launching `antigravity-ide` or `ag` causes the app to exit immediately or fail silently. In verbose mode (`~/.local/share/antigravity-ide/antigravity-ide --verbose`), the following error appears:

```text
[FATAL:sandbox/linux/suid/client/setuid_sandbox_host.cc:166] The SUID sandbox helper binary was found, but is not configured correctly. Rather than run without sandboxing I'm aborting now. You need to make sure that /home/tom/.local/share/antigravity-ide/chrome-sandbox is owned by root and has mode 4755.
```

#### Cause
Ubuntu 24.04+ / 26.04+ restricts unprivileged user namespaces (`kernel.apparmor_restrict_unprivileged_userns = 1`). User-local installs lack an AppArmor profile granting `userns` permissions, and user-extracted `chrome-sandbox` lacks root SUID permissions (`4755`).

#### Solutions

##### Option 1: Create an AppArmor Profile (Recommended)
```bash
sudo tee /etc/apparmor.d/antigravity-ide << 'EOF'
abi <abi/5.0>,
include <tunables/global>

profile antigravity-ide /home/*/.local/share/antigravity-ide/antigravity-ide flags=(unconfined) {
  userns,
  @{exec_path} mr,

  include if exists <local/antigravity-ide>
}
EOF

sudo apparmor_parser -r /etc/apparmor.d/antigravity-ide
```

##### Option 2: Set Root SUID Permissions on `chrome-sandbox`
```bash
sudo chown root:root ~/.local/share/antigravity-ide/chrome-sandbox
sudo chmod 4755 ~/.local/share/antigravity-ide/chrome-sandbox
```

##### Option 3: Disable AppArmor Namespace Restrictions System-Wide
```bash
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
```

##### Option 4: Non-Root Workaround (`--no-sandbox`)
If `sudo` privileges are not available, configure Antigravity IDE to pass `--no-sandbox` automatically:
1. **Update CLI Launcher Script** in `~/.local/share/antigravity-ide/bin/antigravity-ide`:
   ```bash
   ELECTRON_RUN_AS_NODE=1 "$ELECTRON" "$CLI" --no-sandbox "$@"
   ```
2. **Desktop Launcher** in `~/.local/share/applications/antigravity-ide.desktop`:
   ```ini
   Exec=/home/tom/.local/bin/antigravity-ide %F
   ```


