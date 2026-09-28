#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
desktop=/home/deck/.local/share/applications/Android-TV-16-Steam.desktop
[[ -f "$desktop" ]] || { echo 'Run bash install.sh first.' >&2; exit 1; }
command -v steamos-add-to-steam >/dev/null || { echo 'Use Steam: Games > Add a Non-Steam Game > Android TV 16.' >&2; exit 1; }
# Steam owns its live shortcut database. Do not edit shortcuts.vdf behind it.
exec steamos-add-to-steam "$desktop"
