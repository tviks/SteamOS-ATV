#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -uo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/bin
unset LD_LIBRARY_PATH LD_PRELOAD PYTHONPATH PYTHONHOME
export XDG_DATA_HOME=/home/deck/.local/share/waydroid-atv16
failures=0
check() {
    if "$@"; then printf 'OK: %s\n' "$*"; else printf 'FAIL: %s\n' "$*"; failures=$((failures+1)); fi
}
if [[ -r /etc/os-release ]]; then cat /etc/os-release; fi
check test "$(id -un)" = deck
check test "$(id -u)" = 1000
check command -v waydroid
check command -v socat
check command -v firewall-cmd
check test -x /usr/bin/waydroid-mount
check test -x /home/deck/.local/opt/steamos-waydroid/current/bin/cage
check test -x /home/deck/.local/opt/steamos-waydroid/current/bin/wlr-randr
bundle=/home/deck/.local/opt/steamos-waydroid/current
if [[ -x $bundle/tools/check-bundle-target.sh ]]; then
    check "$bundle/tools/check-bundle-target.sh" "$bundle"
fi
check test -s /home/deck/Android_Waydroid_ATV16/var-lib-waydroid/images/system.img
check test -s /home/deck/Android_Waydroid_ATV16/var-lib-waydroid/images/vendor.img
check test -x /etc/waydroid-atv16/control
check test -r /etc/waydroid-atv16/launcher-logging.sh
check test -f /etc/udev/rules.d/72-waydroid-atv16-remote.rules
check sudo -n /etc/waydroid-atv16/control check
if mountpoint -q /var/lib/waydroid; then
    waydroid status || true
    systemctl --no-pager --full status waydroid-atv16-controller.service waydroid-atv16-mdns.service waydroid-atv16-remote-6466.service waydroid-atv16-remote-6467.service || true
else
    echo 'TV is stopped: its state is deliberately unmounted; runtime services are absent.'
fi
printf '\nLaunch log: /home/deck/Android_Waydroid_ATV16/steam-launch.log\n'
exit "$((failures > 0))"
