#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
project=$(cd -- "$(dirname -- "$0")/.." && pwd)
bootstrap=false
repair=false
for argument in "$@"; do
    case "$argument" in
        --bootstrap) bootstrap=true ;;
        --repair) repair=true ;;
        --help|-h)
            echo 'Usage: bash install.sh [--bootstrap] [--repair]'
            echo '--bootstrap: install/repair the SteamOS Waydroid host bundle interactively.'
            echo '--repair: refresh TV integration without downloading/replacing Android images.'
            exit 0 ;;
        *) echo "Unknown argument: $argument" >&2; exit 2 ;;
    esac
done
export PATH=/usr/local/sbin:/usr/local/bin:/usr/bin
unset LD_LIBRARY_PATH LD_PRELOAD PYTHONPATH PYTHONHOME
[[ $(id -un) = deck && $EUID = 1000 && $HOME = /home/deck ]] || { echo 'This kit supports the standard deck account (UID 1000, /home/deck).' >&2; exit 1; }
[[ $(uname -m) = x86_64 ]] || { echo 'x86_64 Steam Deck required.' >&2; exit 1; }
source /etc/os-release
[[ ${ID:-} = steamos ]] || { echo 'SteamOS required.' >&2; exit 1; }
if $bootstrap; then bash "$project/scripts/bootstrap.sh"; fi
for command in waydroid python3 curl unzip sha256sum sudo; do
    command -v "$command" >/dev/null || { echo "Missing $command; install the SteamOS host bundle first." >&2; exit 1; }
done
for dependency in /usr/bin/waydroid-mount /home/deck/.local/opt/steamos-waydroid/current/bin/cage /home/deck/.local/opt/steamos-waydroid/current/bin/wlr-randr; do
    [[ -x $dependency ]] || { echo "Missing $dependency; run bash install.sh --bootstrap." >&2; exit 1; }
done
python3 -c 'from packaging.version import Version; import subprocess; v=subprocess.check_output(["waydroid","--version"],text=True).strip(); assert Version(v)>=Version("1.6.3"), "Waydroid 1.6.3 or newer required"'
bundle=/home/deck/.local/opt/steamos-waydroid/current
"$bundle/tools/check-bundle-target.sh" "$bundle"
state=/home/deck/Android_Waydroid_ATV16/var-lib-waydroid
cache=/home/deck/.cache/android-tv16-install
if [[ ! -f $state/waydroid.cfg ]]; then
    $repair && { echo 'No TV installation to repair.' >&2; exit 1; }
    if [[ -e $state || -e /home/deck/.local/share/waydroid-atv16 ]]; then
        echo 'Uninitialized TV state or user data already exists. Inspect/back it up; nothing was overwritten.' >&2
        exit 1
    fi
    available=$(df -Pk /home/deck | awk 'NR==2 {print $4}')
    (( available >= 8*1024*1024 )) || { echo 'At least 8 GiB free needed for this TV stage.' >&2; exit 1; }
    mkdir -p "$cache"
    download() {
        local filename=$1 checksum=$2 kind=$3
        local path="$cache/$filename"
        if [[ -f $path ]] && printf '%s  %s\n' "$checksum" "$path" | sha256sum -c -; then return; fi
        curl --fail --location --retry 3 --connect-timeout 30 \
            "https://sourceforge.net/projects/waydroid-atv/files/images/$kind/waydroid_tv_x86_64/$filename/download" -o "$path.part"
        printf '%s  %s\n' "$checksum" "$path.part" | sha256sum -c -
        mv -- "$path.part" "$path"
    }
    download lineage-23.0-20260403-GAPPS-waydroid_tv_x86_64-system.zip ddf5995f9104fe7164ad326def8bbed5cbf6340b55da5012e240b5855c44953b system
    download lineage-23.0-20260403-MAINLINE-waydroid_tv_x86_64-vendor.zip 8b8b176c7d3b34719889f3c891d86b98af8dbbb2f737a970e89302fa3d0cf077 vendor
else
    echo 'Existing TV installation: preserving images, applications and pairing.'
fi
sudo bash "$project/scripts/install-root.sh" "$project" "$cache"
install -m 755 "$project/runtime/Android-TV-16-Steam.sh" /home/deck/Android-TV-16-Steam.sh
mkdir -p /home/deck/.local/share/applications
install -m 755 "$project/runtime/Android-TV-16-Steam.desktop" /home/deck/.local/share/applications/Android-TV-16-Steam.desktop
echo 'Installed. Run bash add-to-steam.sh once, then launch Android TV 16 in Gaming Mode.'
