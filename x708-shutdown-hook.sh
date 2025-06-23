#!/bin/sh
# Shutdown hook to pulse the X708 power-off signal.
# Runs in the final stage of shutdown with the root filesystem read-only.
# Only act on an actual power-off, not a reboot.
[ "$1" = "poweroff" ] || exit 0
/usr/local/bin/x708-softsd.sh 4

