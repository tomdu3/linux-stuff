# Running Windows on Omarchy

Omarchy ships a Windows VM built on Docker + QEMU using the
[`dockur/windows`](https://github.com/dockur/windows) image. Everything below
drives the same container via `omarchy-windows-vm`.

## Quick reference

| Action               | Command / UI                                            |
| -------------------- | ------------------------------------------------------- |
| First-time install   | `omarchy windows vm install`                            |
| Launch + RDP connect | Launcher (`Super+Space` → Windows) or `omarchy windows vm launch` |
| Keep running         | `omarchy windows vm launch --keep-alive`                |
| Stop                 | `omarchy windows vm stop`                               |
| Status               | `omarchy windows vm status`                             |
| Remove               | `omarchy windows vm remove`                             |

The bare helper `omarchy-windows-vm` accepts the same subcommands
(`install`, `launch`, `stop`, `status`, `remove`, `help`).

## How it works

- Runs as the Docker container `omarchy-windows` (mirror: `dockurr/windows`).
- Compose file: `/var/lib/omarchy/windows/docker-compose.yml` (root-owned).
- Web console (VNC/novnc): <http://127.0.0.1:8006>
- RDP: `127.0.0.1:3389`
- Disk + data: `/var/lib/omarchy/windows/mounts/users/1000/{storage,shared}`
  (bind-mounted into the guest as `C:\` drives at `/storage` and `/shared`).
- Privileged Docker operations are elevated via a polkit prompt; you may be
  asked for authorization once per action.

## First install

```bash
omarchy windows vm install
```

Answer the prompts (RAM, cores, disk size, Windows username/password). A
desktop entry `windows-vm.desktop` is created and a browser opens
<http://127.0.0.1:8006> to watch the unattended Windows setup.

## Everyday use

Launch from the app launcher (`Super+Space` → Windows) or run:

```bash
omarchy windows vm launch           # connects via RDP; VM auto-stops when RDP closes
omarchy windows vm launch --keep-alive   # VM stays up after you close RDP
```

Check state:

```bash
omarchy windows vm status
```

Stop manually:

```bash
omarchy windows vm stop
```

> Because the default launch is `--keep-alive=false`, closing the RDP window
> shuts the VM down. That is expected, not an error.

## Troubleshooting

### "Windows VM is stopped / cannot start" after using the web UI shutdown button

The novelty button in the web console (<http://127.0.0.1:8006>) sends a grace
ful shutdown to the guest. The container then exits cleanly (code 0). The
compose file sets `restart: 'no'`, so it stays stopped until you start it —
the VM is **not** broken and the disk is not corrupted.

Start it the normal way:

```bash
omarchy windows vm launch
```

If the launcher or CLI wrapper keeps failing with a generic message, start the
container directly:

```bash
sudo docker-compose -f /var/lib/omarchy/windows/docker-compose.yml up -d
```

Then verify:

```bash
sudo docker ps --filter name=omarchy-windows
```

You should see `Up` shortly after, and the guest is reachable via RDP / the web
console.

### "Exited (0)" in `docker ps`

Normal. It means Windows shut down cleanly (browser shutdown button, or RDP
auto-stop). Start it with the commands above.

### Launching always fails / authorization declines

The helper elevates via `pkexec`; make sure you are in an active graphical
session and approve the polkit prompt. Each elevated action prompts once.

### Status shows "exited" but Windows booted fine in web UI

The web console reports "Windows started successfully" once booted — if RDP was
closed or already disconnected, the VM may have auto-stopped. Relaunch.

## Known warnings (non-fatal)

- `/storage` sits on **btrfs**; dockur warns this "might introduce issues with
  Windows Setup". Windows is already installed here, so it is informational.
- QEMU reports an unsupported clock source (`hpet`); the host should expose
  `tsc`. Windows still boots, but performance/timing guests should be aware.

## Uninstall

```bash
omarchy windows vm remove
```

Backs up nothing — it deletes the container **and** the disk under
`/var/lib/omarchy/windows/mounts/users/1000/storage`. Confirm the prompt.