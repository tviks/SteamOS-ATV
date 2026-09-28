#!/bin/bash
set -Eeuo pipefail
export PATH=/usr/local/bin:/usr/bin
unset LD_LIBRARY_PATH LD_PRELOAD PYTHONPATH PYTHONHOME
export XDG_RUNTIME_DIR=/run/user/1000
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
export XDG_DATA_HOME=/home/deck/.local/share/waydroid-atv16
export WLR_BACKENDS=x11
unset WAYLAND_DISPLAY
export DISPLAY=${DISPLAY:-:0}
base=/home/deck/Android_Waydroid_ATV16
mkdir -p "$base"
exec 8>"$XDG_RUNTIME_DIR/android-tv16-launch.lock"
flock -n 8 || exit 0
source /etc/waydroid-atv16/launcher-logging.sh
setup_launch_logging "$base/steam-launch.log"
printf '\nAndroid TV 16 launch: %s\n' "$(date -Is)"
control=/etc/waydroid-atv16/control
sudo -n "$control" check
bundle=/home/deck/.local/opt/steamos-waydroid/current
"$bundle/tools/check-bundle-target.sh" "$bundle"
/usr/bin/waydroid session stop || true
sudo -n "$control" start
cleanup() {
    trap - EXIT
    /usr/bin/waydroid session stop || true
    sudo -n "$control" stop || true
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM
cage=/home/deck/.local/opt/steamos-waydroid/current/bin/cage
randr=/home/deck/.local/opt/steamos-waydroid/current/bin/wlr-randr
"$cage" -- /bin/bash -c '
    "$1" --output X11-1 --custom-mode 1280x720 || true
    /usr/bin/waydroid show-full-ui &
    ui=$!
    ready=false
    for ((i=0; i<45; i++)); do
        if /usr/bin/waydroid status | grep -q "IP address:.*192\.168\.240\."; then
            sleep 3
            if ! sudo -n /etc/waydroid-atv16/control input; then
                echo "Failed to initialize Android TV input/remote services." >&2
                kill "$ui" 2>/dev/null || true
                wait "$ui" || true
                exit 1
            fi
            ready=true
            break
        fi
        kill -0 "$ui" 2>/dev/null || break
        sleep 1
    done
    if ! $ready && kill -0 "$ui" 2>/dev/null; then
        echo "Android TV network did not become ready within 45 seconds." >&2
        kill "$ui" 2>/dev/null || true
        wait "$ui" || true
        exit 1
    fi
    wait "$ui"
' bash "$randr"
