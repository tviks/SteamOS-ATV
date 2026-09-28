#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Keep a real user-owned log FD out of privileged/container descendants.
setup_launch_logging() {
    local log=$1
    [[ ! -L $log ]] || { echo 'Refusing a symlink launch log.' >&2; return 1; }
    if [[ -e $log && ! -w $log ]]; then
        # deck owns the directory: recover a legacy log without privileged chown.
        mv -f -- "$log" "${log%.log}.previous.log"
    fi
    : >> "$log"
    # Only tee opens the file. Android and sudo inherit a pipe, not this FD.
    # Do not let the logger retain the launcher's single-instance lock.
    exec > >(exec 8>&-; exec tee -a -- "$log") 2>&1
}
