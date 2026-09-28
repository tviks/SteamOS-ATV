#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/bin
unset LD_LIBRARY_PATH LD_PRELOAD PYTHONPATH PYTHONHOME
export XDG_DATA_HOME=/home/deck/.local/share/waydroid-atv16
[[ $EUID = 0 && $# = 2 ]] || { echo 'Internal entry point: use install.sh.' >&2; exit 2; }
project=$(realpath -- "$1")
cache=$(realpath -- "$2")
state=/home/deck/Android_Waydroid_ATV16/var-lib-waydroid
target=/var/lib/waydroid
image_mount=
mounted=false
readonly_changed=false
cleanup() {
    status=$?
    trap - EXIT
    [[ -z $image_mount ]] || { umount "$image_mount" || true; rmdir "$image_mount" || true; }
    if $mounted; then umount "$target" || true; fi
    if $readonly_changed; then steamos-readonly enable || true; fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM
# Never take over a live main/test/TV Android instance.
if mountpoint -q "$target" || findmnt -rn -o TARGET | grep -q '^/var/lib/waydroid/'; then
    echo 'A Waydroid environment is mounted. Close it or reboot, then retry.' >&2; exit 1
fi
if systemctl is-active --quiet waydroid-container.service; then
    echo 'Waydroid is running. Close it or reboot, then retry.' >&2; exit 1
fi
unit_exec=$(systemctl cat waydroid-container.service | sed -n 's/^ExecStart=//p' | tail -n 1)
[[ $unit_exec = *'/usr/bin/waydroid'* ]] || { echo 'Unexpected Waydroid service executable; inspect the service.' >&2; exit 1; }
if ! command -v socat >/dev/null; then
    if [[ $(steamos-readonly status) = enabled ]]; then
        steamos-readonly disable
        readonly_changed=true
    fi
    pacman -S --needed socat
fi
for dependency in python3 firewall-cmd udevadm visudo unzip sha256sum; do command -v "$dependency" >/dev/null; done
mkdir -p /home/deck/Android_Waydroid_ATV16
chown deck:deck /home/deck/Android_Waydroid_ATV16
if [[ ! -f $state/waydroid.cfg ]]; then
    [[ ! -e $state && ! -e $XDG_DATA_HOME ]] || { echo 'Uninitialized TV state exists; refusing replacement.' >&2; exit 1; }
    system_zip="$cache/lineage-23.0-20260403-GAPPS-waydroid_tv_x86_64-system.zip"
    vendor_zip="$cache/lineage-23.0-20260403-MAINLINE-waydroid_tv_x86_64-vendor.zip"
    printf '%s  %s\n' ddf5995f9104fe7164ad326def8bbed5cbf6340b55da5012e240b5855c44953b "$system_zip" | sha256sum -c -
    printf '%s  %s\n' 8b8b176c7d3b34719889f3c891d86b98af8dbbb2f737a970e89302fa3d0cf077 "$vendor_zip" | sha256sum -c -
    mkdir -p "$state/images"
    unzip -p "$system_zip" system.img > "$state/images/system.img"
    unzip -p "$vendor_zip" vendor.img > "$state/images/vendor.img"
    install -m 644 "$project/runtime/waydroid.cfg" "$state/waydroid.cfg"
else
    # Refuse to apply release-specific fixes to a different image or profile.
    grep -q '^system_datetime = 1775195212$' "$state/waydroid.cfg"
    grep -q '^vendor_datetime = 1775149178$' "$state/waydroid.cfg"
    grep -q 'a16-tv/system/lineage/waydroid_x86_64/GAPPS.json' "$state/waydroid.cfg"
fi
[[ -s $state/images/system.img && -s $state/images/vendor.img ]]
mkdir -p "$state/rootfs" "$state/overlay/system/bin" "$state/overlay/vendor" "$state/overlay_rw/system" "$state/overlay_rw/vendor" "$state/overlay_work/system" "$state/overlay_work/vendor"
# Generate LXC/properties offline from the pinned image configuration. This
# avoids init preferring another Android's /etc/waydroid-extra/images symlink.
source /usr/bin/waydroid-mount
validate_binder
mkdir -p "$target"
mount --bind "$state" "$target"
mounted=true
/usr/bin/waydroid upgrade -o
umount "$target"
mounted=false
# Keep the original bpfloader in the overlay and provide its inherited FD.
if [[ ! -s $state/overlay/system/bin/bpfloader-original ]]; then
    image_mount=$(mktemp -d /run/waydroid-atv16-install.XXXXXX)
    mount -o loop,ro "$state/images/system.img" "$image_mount"
    cp -p "$image_mount/system/bin/bpfloader" "$state/overlay/system/bin/bpfloader-original"
    umount "$image_mount"
    rmdir "$image_mount"
    image_mount=
fi
install -m 755 "$project/runtime/bpfloader-wrapper.sh" "$state/overlay/system/bin/bpfloader"
backup=/etc/waydroid-atv16/backups/$(date +%Y%m%d-%H%M%S)-$$
mkdir -p "$backup" /etc/udev/rules.d /etc/sudoers.d
for name in control controller-hotplug remote-start remote-stop mdns.py launcher-logging.sh; do
    [[ ! -f /etc/waydroid-atv16/$name ]] || cp -a "/etc/waydroid-atv16/$name" "$backup/$name"
done
for path in /etc/udev/rules.d/72-waydroid-atv16-remote.rules /etc/sudoers.d/zzzzzzzzzz-waydroid-atv16; do
    [[ ! -f $path ]] || cp -a "$path" "$backup/"
done
install -o root -g root -m 755 "$project/runtime/waydroid-atv16-control" /etc/waydroid-atv16/control
install -o root -g root -m 755 "$project/runtime/atv16-controller-hotplug" /etc/waydroid-atv16/controller-hotplug
install -o root -g root -m 755 "$project/runtime/atv16-remote-start" /etc/waydroid-atv16/remote-start
install -o root -g root -m 755 "$project/runtime/atv16-remote-stop" /etc/waydroid-atv16/remote-stop
install -o root -g root -m 644 "$project/runtime/atv16-mdns.py" /etc/waydroid-atv16/mdns.py
install -o root -g root -m 644 "$project/runtime/launcher-logging.sh" /etc/waydroid-atv16/launcher-logging.sh
install -o root -g root -m 644 "$project/runtime/72-waydroid-atv16-remote.rules" /etc/udev/rules.d/72-waydroid-atv16-remote.rules
visudo -cf "$project/runtime/waydroid-atv16-sudoers"
install -o root -g root -m 440 "$project/runtime/waydroid-atv16-sudoers" /etc/sudoers.d/zzzzzzzzzz-waydroid-atv16
udevadm control --reload-rules
echo 'Root integration installed; existing TV data was not erased.'
