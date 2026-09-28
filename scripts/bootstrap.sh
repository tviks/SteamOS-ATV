#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
[[ $(id -un) = deck && $EUID = 1000 ]] || { echo 'Run locally as deck in SteamOS Desktop Mode.' >&2; exit 1; }
[[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} && -z ${SSH_CONNECTION:-} ]] || { echo 'Open Konsole on the Deck in Desktop Mode (not SSH).' >&2; exit 1; }
repo=/home/deck/steamos-waydroid-bundle
revision=8f5cc2a4f55010dc480f153350a7547b501fd49f
if [[ ! -e $repo ]]; then
    git clone https://github.com/pjohno/steamos-waydroid-bundle.git "$repo"
    git -C "$repo" checkout --detach "$revision"
else
    [[ -d $repo/.git && -f $repo/steamos-waydroid-installer.sh ]] || { echo 'Existing bundle directory is not a checkout; inspect it manually.' >&2; exit 1; }
    echo 'Using the existing bundle checkout without resetting or updating it.'
    git -C "$repo" rev-parse HEAD
fi
echo 'Install/repair the host bundle. On a fresh Deck choose a normal Android 13 image.'
echo 'At the end choose NO when offered a return to Gaming Mode.'
bash "$repo/steamos-waydroid-installer.sh"
