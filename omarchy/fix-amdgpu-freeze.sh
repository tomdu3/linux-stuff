#!/usr/bin/env bash
#
# fix-amdgpu-freeze.sh
#
# Applies kernel command-line stability parameters to stop the recurring
# hard freezes (black screens -> total hang -> power cycle) on this
# AMD Ryzen 5 3400G / Radeon Vega (amdgpu) system.
#
# Full investigation: ~/Work/CRASH_ISSUES.md
#
# Parameters added (via /etc/limine-entry-tool.d drop-in, the Omarchy way):
#   - iommu=pt            avoid AMD-Vi IO_PAGE_FAULT churn on the NVMe
#   - amdgpu.aspm=0       disable PCIe ASPM on the GPU (a known freeze trigger)
#   - clocksource=hpet    stop relying on the repeatedly-unstable TSC
#
# Usage:  bash fix-amdgpu-freeze.sh        (asks for sudo once)
# Revert: rm /etc/limine-entry-tool.d/99-amdgpu-fix.conf && re-run this script
#         (it regenerates the boot entry without the extra parameters)

set -euo pipefail

CONF=/etc/limine-entry-tool.d/99-amdgpu-fix.conf
ESP_PATH="${ESP_PATH:-/boot}"

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

# 1. Write the kernel-cmdline drop-in (idempotent).
mkdir -p /etc/limine-entry-tool.d
cat > "$CONF" <<'EOF'
# AMD 3400G (Picasso/Vega) hard-freeze workaround — see ~/Work/CRASH_ISSUES.md
KERNEL_CMDLINE[default]+=" iommu=pt amdgpu.aspm=0 clocksource=hpet"
EOF
echo "Wrote $CONF:"
cat "$CONF"

# 2. Regenerate the boot entry so the new cmdline lands in limine.conf.
#    This mirrors exactly what Omarchy's mkinitcpio install hook does
#    (limine-entry-tool --add-uki <name> <uki> --comment <comment>),
#    re-pointing at the UKI file that is already deployed on the ESP.

# Try Omarchy's custom UKI prefix first, then the machine-id prefix.
UKI_DIRS=("$ESP_PATH/$([ -n "${CUSTOM_UKI_NAME:-}" ] && echo "$CUSTOM_UKI_NAME" || echo omarchy)"
          "$ESP_PATH/$(cat /etc/machine-id 2>/dev/null)")
regenerated=0
for dir in "${UKI_DIRS[@]}"; do
    if compgen -G "$dir/*.efi" >/dev/null 2>&1; then
        for uki in "$dir"/*.efi; do
            name=$(basename "$uki" .efi)
            ver=$(uname -r)
            pkgbase=$(cat "/usr/lib/modules/$(uname -r)/pkgbase" 2>/dev/null || echo linux)
            echo "-> Re-registering boot entry '$name' ($uki)"
            limine-entry-tool --add-uki "$name" "$uki" --comment "Kernel version: $ver" \
                || limine-entry-tool --add-uki "$name" "$uki"
            regenerated=1
        done
        break
    fi
done

if [ "$regenerated" -eq 0 ]; then
    echo
    echo "NOTE: no UKI found under $ESP_PATH — could not refresh the boot entry."
    echo "Regenerate it manually after the next kernel update, or run:"
    echo "  sudo limine-entry-tool --add-uki linux /boot/omarchy/linux.efi"
fi

echo
echo "Done. The new kernel options take effect after the next reboot."
echo "Verify afterwards with:  cat /proc/cmdline"
echo "  (must contain: iommu=pt amdgpu.aspm=0 clocksource=hpet)"
echo "Revert any time with:    sudo rm $CONF && bash $(readlink -f "$0")"