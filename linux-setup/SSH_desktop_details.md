# SSH & SSHFS Configuration Guide

This document summarizes the SSH and SSHFS configuration, key mappings, port forwardings, and shell helpers configured on this system.

---

## 1. Directory Structure & Permissions

OpenSSH enforces strict file permission standards. The files and directories are configured as follows:

| Path | Permissions | Type | Purpose |
| :--- | :--- | :--- | :--- |
| `~/.ssh/` | `700` (`drwx------`) | Directory | Primary SSH configuration & key storage |
| `~/.ssh/agent/` | `700` (`drwx------`) | Directory | SSH agent socket runtime directory |
| `~/.sshfs/` | `700` (`drwx------`) | Directory | SSHFS runtime / cache directory |
| `~/.ssh/config` | `600` (`-rw-------`) | File | Client host configurations and aliases |
| `~/.ssh/authorized_keys` | `600` (`-rw-------`) | File | Public keys authorized for inbound SSH |
| `~/.ssh/known_hosts` | `600` (`-rw-------`) | File | Host keys of previously connected servers |
| `~/.ssh/*` (Private Keys) | `600` (`-rw-------`) | File | Private identity keys |
| `~/.ssh/*.pub` (Public Keys) | `644` (`-rw-r--r--`) | File | Public identity keys |

---

## 2. Configured SSH Keys

The following SSH key pairs are present in `~/.ssh/`:

- **Homelab Key**:
  - Private: `~/.ssh/id_ed25519_hl`
  - Public: `~/.ssh/id_ed25519_hl.pub`
- **DigitalOcean Key**:
  - Private: `~/.ssh/id_ed25519_digitalocean`
  - Public: `~/.ssh/id_ed25519_digitalocean.pub`
- **Contabo Key**:
  - Private: `~/.ssh/contabo_rsa`
  - Public: `~/.ssh/contabo_rsa.pub`
- **Default RSA Key**:
  - Private: `~/.ssh/id_rsa`
  - Public: `~/.ssh/id_rsa.pub`

---

## 3. SSH Client Configuration (`~/.ssh/config`)

### Host: `homelab`
```ssh-config
Host homelab
    HostName 192.168.0.50
    User tom
    IdentityFile ~/.ssh/id_ed25519_hl
    LocalForward 3000 127.0.0.1:3000
    LocalForward 8000 127.0.0.1:8000
    LocalForward 9000 127.0.0.1:9000
```

#### Port Forwarding Details:
When connecting via `ssh homelab`, the following local ports are forwarded to the remote host:
- **Port 3000** &rarr; `127.0.0.1:3000` (Web Application / Frontend)
- **Port 8000** &rarr; `127.0.0.1:8000` (FastAPI / Python Backend)
- **Port 9000** &rarr; `127.0.0.1:9000` (Portainer Management)

---

## 4. SSHFS & FUSE Setup

- **SSHFS Binary**: Installed via Homebrew (`/home/linuxbrew/.linuxbrew/bin/sshfs`, `v3.7.6`).
- **Binary Symlinks**: Available in `~/.local/bin/sshfs` and directly in `$PATH`.
- **FUSE Driver**: Backed by `fusermount3` (`v3.18.2` / `v3.14.0`) with standard user access via `/dev/fuse`.

---

## 5. Shell Shortcuts & Workflows (Bash & Zsh)

The following helper aliases are configured in both `~/.bashrc` and `~/.zshrc`:

| Command | Action | Description |
| :--- | :--- | :--- |
| `lab-mount` | `mkdir -p ~/remote-projects/homelab && sshfs homelab:/home/$(whoami) ~/remote-projects/homelab` | Mounts the remote homelab home directory to local `~/remote-projects/homelab` |
| `lab-unmount` | `fusermount -u ~/remote-projects/homelab \|\| umount ~/remote-projects/homelab` | Safely unmounts the remote filesystem |
| `lab-code` | `cd ~/remote-projects/homelab && nvim .` | Enters the homelab directory and launches Neovim |
| `lab-ag` | `mkdir -p ~/remote-projects/homelab && cd ~/remote-projects/homelab && antigravity-ide .` | Enters the homelab directory and opens Antigravity IDE |

---

## 6. Quick Usage Guide

### Connect via SSH:
```bash
ssh homelab
```

### Mount and work on remote projects locally:
```bash
# 1. Mount remote homelab filesystem
lab-mount

# 2. Open in Antigravity IDE or Neovim
lab-ag
# or:
lab-code

# 3. Unmount when finished
lab-unmount
```
