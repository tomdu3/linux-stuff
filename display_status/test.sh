echo "=== SYSTEM INFO ==="
uptime
echo -e "\n=== LAST 50 GPU KERNEL ERRORS ==="
sudo dmesg | grep -i -E "amdgpu|drm|fence|ring.*timeout|gpu.*reset|card1|radeon" | tail -50

echo -e "\n=== RECENT JOURNAL GPU ERRORS ==="
sudo journalctl -k -n 100 --no-pager | grep -i -E "amdgpu|drm|fence|timeout|hang|reset|gpu"

echo -e "\n=== DISPLAY SERVER STATUS ==="
echo "Current session: $XDG_SESSION_TYPE"
echo "WM: $XDG_CURRENT_DESKTOP"

echo -e "\n=== COSMIC COMP LOGS (last 30 lines) ==="
journalctl -u cosmic-comp -n 30 --no-pager 2>/dev/null || echo "Not available"

echo -e "\n=== GPU CURRENT STATE ==="
cat /sys/class/drm/card1/device/power_dpm_force_performance_level 2>/dev/null
cat /sys/class/drm/card1/device/pp_dpm_sclk 2>/dev/null | tail -1
cat /sys/class/drm/card1/device/pp_dpm_mclk 2>/dev/null | tail -1

echo -e "\n=== GPU TEMPERATURE ==="
find /sys/class/drm/card1/device/hwmon/ -name "temp*_input" 2>/dev/null | while read f; do echo "$(basename $(dirname $f)): $(($(cat $f) / 1000))°C"; done

echo -e "\n=== RECENT SYSTEM LOGS (last 5 minutes) ==="
journalctl --since "5 minutes ago" --no-pager | tail -30
