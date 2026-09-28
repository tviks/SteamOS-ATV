#!/system/bin/sh
# Android 16's Rust loader requires the descriptor normally supplied by init.
# Keep it valid across netbpfload's exec on the SteamOS Waydroid host.
exec 3>>/data/bpfloader-debug.log
export ANDROID_FILE__dev_kmsg=3
echo "bpfloader wrapper starting" >&3
/system/bin/bpfloader-original "$@" >>/data/bpfloader-debug.log 2>&1
result=$?
echo "bpfloader exit: $result" >&3
exit "$result"
