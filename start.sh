#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
launcher=/home/deck/Android-TV-16-Steam.sh
[[ -x "$launcher" ]] || { echo 'Run bash install.sh first.' >&2; exit 1; }
exec "$launcher"
