#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
exec bash "$(cd -- "$(dirname -- "$0")" && pwd)/scripts/install.sh" "$@"
