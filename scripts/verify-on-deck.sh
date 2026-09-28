#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Read-only package verification. Does not install, restart or reset Android.
set -euo pipefail
project=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project"
python3 -m unittest discover -s tests -v
bash install.sh --help
bash doctor.sh
