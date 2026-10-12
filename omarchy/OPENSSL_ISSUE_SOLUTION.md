# openssl-1.1 AUR update failure — diagnosis and fix

## Symptom

System update aborts with:

```
-> Failed to install the following packages. Manual intervention is required:
openssl-1.1 - exit status 4
```

The failure occurs in `check()` while building the AUR package `openssl-1.1`
(version `1.1.1.w`, going from `pkgrel 11` -> `pkgrel 13`).

## Root cause

The running kernel (`7.2.5-3-omarchy`) ships the new
`crypto.af_alg_restrict = 1` sysctl.

Since Linux 7.3 (backported into this kernel), AF_ALG only supports a small
per-algorithm allowlist. Several allowlisted entries are marked
**privileged-only** (`CAP_NET_ADMIN` / `CAP_SYS_ADMIN` in the initial user
namespace), including `cbc(aes)`. When an **unprivileged** process (like
`makepkg` running as `tom`) tries to `bind()` such an algorithm, the kernel
returns `ENOENT`:

```
ALG_PERR: engines/e_afalg.c(383): Failed to bind socket : No such file or directory
...
Test Summary Report
../test/recipes/30-test_afalg.t   (Wstat: 256 (exited 1) Tests: 1 Failed: 1)
  Failed test:  1
Files=160, Tests=2667, ... 
Result: FAIL
make: *** [Makefile:205: tests] Error 2
==> ERROR: A failure occurred in check().
```

The upstream test `test/recipes/30-test_afalg.t` binds `cbc(aes)` via the
`afalg` engine, which is now blocked for unprivileged users, so `check()`
always fails. All other 2667 tests pass.

This is a **test / environment incompatibility**, not a defect in the package
or in the CVE patches. Earlier builds (e.g. `pkgrel 11` on 2026-09-30)
succeeded before the kernel restriction was in effect.

### Direct confirmation

```console
$ sysctl crypto.af_alg_restrict
crypto.af_alg_restrict = 1

$ python3 - <<'EOF'
import socket
for typ, name in [("skcipher", "cbc(aes)"), ("hash", "sha256")]:
    try:
        s = socket.socket(socket.AF_ALG, socket.SOCK_SEQPACKET, 0)
        s.bind((typ, name))
        print("OK  ", typ, name)
    except OSError as e:
        print("FAIL", typ, name, "->", e)
EOF
FAIL skcipher cbc(aes) -> [Errno 2] No such file or directory
FAIL hash sha256 -> [Errno 2] No such file or directory
```

The kernel source allowlist marks `cbc(aes)` as privileged:

```c
static const struct af_alg_allowlist_entry skcipher_allowlist[] = {
    { "cbc(aes)", true },   /* iwd — privileged */
    ...
};
```

`af_alg_restrict` values (from kernel docs):

| Value | Meaning |
|-------|---------|
| 0 | AF_ALG unrestricted |
| 1 | Limited algorithm allowlist (default) |
| 2 | AF_ALG completely disabled |

## Fix applied

Rebuild the package with tests skipped (the code itself compiles cleanly):

```console
$ cd ~/.cache/yay/openssl-1.1
$ makepkg -C -f --nocheck --noconfirm
==> Finished making: openssl-1.1 1.1.1.w-13
```

This produced:

```
~/.cache/yay/openssl-1.1/openssl-1.1-1.1.1.w-13-x86_64.pkg.tar.zst
~/.cache/yay/openssl-1.1/openssl-1.1-debug-1.1.1.w-13-x86_64.pkg.tar.zst
```

Install the package (needs sudo password):

```console
$ sudo pacman -U ~/.cache/yay/openssl-1.1/openssl-1.1-1.1.1.w-13-x86_64.pkg.tar.zst
```

After this, `yay -Sua` sees `1.1.1.w-13` as current and the update proceeds
normally.

## Preventing recurrence

The AUR package version now matches what is installed, so a normal
`omarchy-update` / `yay -Sua` will not rebuild it. It will fail again only when
the AUR bumps `pkgrel`/`pkgver`.

### Option A — skip checks for this build only

```console
$ yay -S --mflags "--nocheck" openssl-1.1
```

### Option B — make yay always pass `--nocheck` (persistent)

Add to `~/.config/yay/config.json`:

```json
{ "mflags": "--nocheck" }
```

Trade-off: disables test-running for **all** AUR packages.

### Option C — disable `check()` globally via makepkg

In `~/.makepkg.conf`, remove `check` from `BUILDENV`:

```bash
BUILDENV=(!distcc color !ccache !check !sign)
```

Trade-off: disables test-running for all packages built with `makepkg`.

### Correct upstream fix

This affects everyone building this AUR package on a kernel with restricted
AF_ALG (Linux >= 7.3). The AUR maintainer should add `options=('!check')` to
the PKGBUILD (or otherwise disable the `afalg` test), or the test should be
adapted to skip when AF_ALG is restricted. Consider reporting it upstream.

## Environment

- OS: Omarchy (Arch-based), kernel `7.2.5-3-omarchy`
- Package: AUR `openssl-1.1` `1.1.1.w-13`
- `crypto.af_alg_restrict = 1`
